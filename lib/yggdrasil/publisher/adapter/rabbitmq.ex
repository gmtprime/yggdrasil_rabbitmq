defmodule Yggdrasil.Publisher.Adapter.RabbitMQ do
  @moduledoc """
  Yggdrasil publisher adapter for RabbitMQ. The name of the channel should be
  a tuple with the name of the exchange and the routing key. The exchange
  should be a topic (or any exhange that redirect to topic) e.g:

  Subscription to channel:

  ```
  iex(1)> name = {"amq.topic", "channel"}
  iex(2)> channel = %Yggdrasil.Channel{name: name, adapter: :rabbitmq}
  iex(3)> Yggdrasil.subscribe(channel)
  :ok
  iex(4)> flush()
  {:Y_CONNECTED, %Yggdrasil.Channel{name: {"amq.topic", "channel"}, (...)}}
  ```

  Publishing message:

  ```
  iex(5)> Yggdrasil.publish(channel, "foo")
  :ok
  ```

  Subscriber receiving message:

  ```
  iex(6)> flush()
  {:Y_EVENT, %Yggdrasil.Channel{name: {"amq.topic", "channel"}, (...)}, "foo"}
  ```

  The subscriber can also unsubscribe from the channel:

  ```
  iex(7)> Yggdrasil.unsubscribe(channel)
  :ok
  iex(8)> flush()
  {:Y_DISCONNECTED, %Yggdrasil.Channel{name: {"amq.topic", "channel"}, (...)}}
  ```
  """
  use GenServer
  use Yggdrasil.Publisher.Adapter

  alias AMQP.Basic
  alias Yggdrasil.Channel
  alias Yggdrasil.RabbitMQ.Client
  alias Yggdrasil.RabbitMQ.Connection.Generator, as: ConnectionGen
  alias Yggdrasil.Transformer

  ############
  # Client API

  @doc """
  Starts a RabbitMQ publisher with a `namespace` for the configuration.
  Additionally, you can add `GenServer` `options`.
  """
  @spec start_link(term()) :: GenServer.on_start()
  @spec start_link(term(), GenServer.options()) :: GenServer.on_start()
  @impl true
  def start_link(namespace, options \\ [])

  def start_link(namespace, options) do
    GenServer.start_link(__MODULE__, namespace, options)
  end

  @doc """
  Stops a RabbitMQ `publisher`. Optionally, receives a stop `reason` (defaults
  to `:normal`) and a `timeout` in milliseconds (defaults to `:infinity`).
  """
  @spec stop(GenServer.name()) :: :ok
  @spec stop(GenServer.name(), term()) :: :ok
  @spec stop(GenServer.name(), term(), non_neg_integer() | :infinity) :: :ok
  defdelegate stop(publisher, reason \\ :normal, timeout \\ :infinity),
    to: GenServer

  @doc """
  Publishes a `message` in a `channel` using a `publisher` server. Optionally,
  it receives a list of options (options expected by `AMQP.Basic.publish/5`).
  """
  @spec publish(GenServer.name(), Channel.t(), term()) ::
          :ok | {:error, term()}
  @spec publish(GenServer.name(), Channel.t(), term(), Keyword.t()) ::
          :ok | {:error, term()}
  @impl true
  def publish(publisher, channel, message, options \\ []) do
    GenServer.call(publisher, {:publish, channel, message, options})
  end

  ####################
  # GenServer callback
  @impl true
  def init(namespace) do
    client = %Client{
      namespace: namespace,
      tag: :publisher,
      pid: self()
    }

    {:ok, client}
  end

  @impl true
  def handle_call(
        {:publish, %Channel{name: {exch, rk}} = channel, message, options},
        _from,
        %Client{} = client
      ) do
    result =
      with {:ok, encoded} <- Transformer.encode(channel, message) do
        ConnectionGen.with_channel(client, fn chan ->
          Basic.publish(chan, exch, rk, encoded, options)
        end)
      end

    {:reply, result, client}
  end
end
