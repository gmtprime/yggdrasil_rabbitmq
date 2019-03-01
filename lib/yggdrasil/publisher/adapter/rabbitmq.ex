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
  use Bitwise

  require Logger

  alias AMQP.Basic
  alias Yggdrasil.Channel
  alias Yggdrasil.RabbitMQ.Connection
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
  @spec stop(GenServer.name(), term(), pos_integer() | :infinity) :: :ok
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
    Process.flag(:trap_exit, true)
    state = %Connection{namespace: namespace}
    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, %Connection{} = state) do
    with {:ok, new_state} <- Connection.connect(state) do
      {:noreply, new_state}
    else
      error ->
        {:noreply, state, {:continue, {:backoff, error}}}
    end
  end

  def handle_continue({:backoff, error}, %Connection{} = state) do
    new_state = Connection.backoff(error, state)
    {:noreply, new_state}
  end

  def handle_continue({:disconnect, _}, %Connection{conn: nil, chan: nil} = state) do
    {:noreply, state}
  end

  def handle_continue({:disconnect, reason}, %Connection{} = state) when reason != :normal do
    new_state = Connection.disconnect(reason, state)
    {:noreply, new_state, {:continue, {:backoff, reason}}}
  end

  @impl true
  def handle_call({:publish, _, _, _}, _from, %Connection{chan: nil} = state) do
    {:reply, {:error, "Disconnected"}, state}
  end

  def handle_call(
        {:publish, %Channel{name: {exchange, routing_key}} = channel,
         message, options},
        _from,
        %Connection{chan: chan} = state
      ) do
    result =
      with {:ok, encoded} <- Transformer.encode(channel, message) do
        Basic.publish(chan, exchange, routing_key, encoded, options)
      end

    {:reply, result, state}
  end

  @impl true
  def handle_info({:timeout, continue}, %Connection{} = state) do
    {:noreply, state, continue}
  end

  def handle_info({:DOWN, _, :process, _, reason}, %Connection{} = state) when reason != :normal do
    {:noreply, state, {:continue, {:disconnect, reason}}}
  end

  def handle_info({:EXIT, _, reason}, %Connection{} = state) when reason != :normal do
    {:noreply, state, {:continue, {:disconnect, reason}}}
  end

  def handle_info(_, %Connection{} = state) do
    {:noreply, state}
  end

  @impl true
  def terminate(:normal, %Connection{} = state) do
    Connection.disconnect(:normal, state)
    :ok
  end

  def terminate(reason, %Connection{} = state) do
    Connection.disconnect(reason, state)
    :ok
  end
end
