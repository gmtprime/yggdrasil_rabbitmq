defmodule Yggdrasil.Subscriber.Adapter.RabbitMQ do
  @moduledoc """
  Yggdrasil subscriber adapter for RabbitMQ. The name of the channel should be
  a tuple with the name of the exchange and the routing key. The exchange
  should be a topic (or any exchange that redirects to topic) e.g:

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
  use Yggdrasil.Subscriber.Adapter

  require Logger

  alias AMQP.Basic
  alias AMQP.Queue
  alias Yggdrasil.Channel
  alias Yggdrasil.RabbitMQ.Client
  alias Yggdrasil.RabbitMQ.Connection
  alias Yggdrasil.RabbitMQ.Connection.Generator, as: ConnectionGen
  alias Yggdrasil.Subscriber.Manager
  alias Yggdrasil.Subscriber.Publisher

  defstruct [:channel, :client, :chan]
  alias __MODULE__, as: State

  ############
  # Client API

  @impl true
  def start_link(channel, options \\ [])

  def start_link(%Channel{} = channel, options) do
    GenServer.start_link(__MODULE__, channel, options)
  end

  ######################
  # Connection callbacks

  @impl true
  def init(%Channel{name: {_, _}, namespace: namespace} = channel) do
    state = %State{
      client: %Client{
        namespace: namespace,
        tag: :subscriber,
        pid: self()
      },
      channel: channel
    }

    {:ok, state, {:continue, :init}}
  end

  @impl true
  def handle_info({:Y_CONNECTED, _}, %State{chan: nil} = state) do
    {:noreply, state, {:continue, :connect}}
  end

  def handle_info({:Y_EVENT, _, :connected}, %State{chan: nil} = state) do
    {:noreply, state, {:continue, :connect}}
  end

  def handle_info(
        {:Y_EVENT, _, :disconnected},
        %State{chan: chan} = state
      ) when not is_nil(chan) do
    {:noreply, state, {:continue, {:disconnect, "Connection down"}}}
  end

  def handle_info(
        {:Y_DISCONNECTED, _},
        %State{chan: chan} = state
      ) when not is_nil(chan) do
    {:noreply, state, {:continue, {:disconnect, "Yggdrasil failure"}}}
  end

  def handle_info({:basic_consume_ok, _}, %State{} = state) do
    {:noreply, state}
  end

  def handle_info({:basic_deliver, message, info}, %State{} = state) do
    notify(message, info, state)
    {:noreply, state}
  end

  def handle_info({:basic_cancel, _}, %State{} = state) do
    {:noreply, state, {:continue, {:disconnect, "Subscription cancelled"}}}
  end

  def handle_info(
        {:DOWN, _, _, pid, reason},
        %State{chan: %{pid: pid}} = state
      ) do
    {:noreply, state, {:continue, {:disconnect, reason}}}
  end

  def handle_info({:EXIT, reason, pid}, %State{chan: %{pid: pid}} = state) do
    {:noreply, state, {:continue, {:disconnect, reason}}}
  end

  def handle_info(_, %State{} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_continue(
        :init,
        %State{
          client: %Client{
            namespace: namespace
          }
        } = state
      ) do
    Connection.subscribe(namespace)
    {:noreply, state}
  end
  def handle_continue(:connect, %State{} = state) do
    with {:ok, new_state} <- connect(state) do
      {:noreply, new_state}
    else
      error ->
        {:noreply, state, {:continue, {:backoff, error}}}
    end
  end

  def handle_continue({:backoff, error}, %State{} = state) do
    backing_off(error, state)
    {:noreply, state}
  end

  def handle_continue({:disconnect, _}, %State{chan: nil} = state) do
    {:noreply, state}
  end

  def handle_continue({:disconnect, reason}, %State{} = state) do
    new_state = disconnect(reason, state)
    {:noreply, new_state, {:continue, {:backoff, reason}}}
  end

  @impl true
  def terminate(reason, %State{chan: nil} = state) do
    terminated(reason, state)
  end

  def terminate(reason, %State{channel: %Channel{} = channel} = state) do
    Manager.disconnected(channel)
    terminated(reason, state)
  end

  #########
  # Helpers

  # Connects to a channel for subscription
  @doc false
  @spec connect(State.t()) :: {:ok, State.t()} | {:error, term()}
  def connect(state)

  def connect(%State{channel: channel} = state) do
    with {:ok, new_state} <- subscribe(state) do
      Manager.connected(channel)
      connected(new_state)
      {:ok, new_state}
    end
  end

  # Subscribes to channel
  defp subscribe(
         %State{
           channel: %Channel{name: {exchange, routing_key}},
           client: client
         } = state
       ) do
    ConnectionGen.with_channel(client, fn chan ->
      with {:ok, %{queue: queue}} <- Queue.declare(chan, "", auto_delete: true),
           :ok <- Queue.bind(chan, queue, exchange, routing_key: routing_key),
           {:ok, _} <- Basic.consume(chan, queue) do
        new_state = %State{state | chan: chan}
        _ = Process.monitor(chan.pid)
        {:ok, new_state}
      end
    end)
  end

  @doc false
  @spec disconnect(term(), State.t()) :: State.t()
  def disconnect(error, state)

  def disconnect(_error, %State{chan: nil} = state) do
    state
  end

  def disconnect(error, %State{channel: %Channel{} = channel} = state) do
    Manager.disconnected(channel)
    disconnected(error, state)
    %State{state | chan: nil}
  end

  @doc false
  def notify(
        message,
        %{
          delivery_tag: tag,
          redelivered: redelivered,
          headers: headers,
          routing_key: routing_key,
          message_id: message_id
        },
        %State{channel: channel, chan: chan}
      ) do
    :ok = Basic.ack(chan, tag)

    metadata = %{
      message_id: message_id,
      headers: headers,
      routing_key: routing_key
    }

    Publisher.notify(channel, message, metadata)
  rescue
    _ ->
      Basic.reject(chan, tag, requeue: not redelivered)
  end

  def notify(_, _, _) do
    :ok
  end

  #################
  # Logging helpers

  # Shows connection message.
  defp connected(%State{channel: channel}) do
    Logger.info("#{__MODULE__} subscribed to #{inspect channel}")
    :ok
  end

  # Shows error when connecting.
  defp backing_off(error, %State{channel: channel}) do
    Logger.warn(
      "#{__MODULE__} cannot subscribe to #{inspect channel}" <>
        " due to #{inspect error}"
    )
    :ok
  end

  # Shows disconnection message.
  defp disconnected(error, %State{channel: %Channel{} = channel}) do
    Logger.warn(
      "#{__MODULE__} unsubscribed from #{inspect(channel)}" <>
        " due to #{inspect error}"
    )
    :ok
  end

  @doc false
  defp terminated(:normal, %State{channel: %Channel{} = channel}) do
    Logger.debug("#{__MODULE__} stopped for #{inspect(channel)}")
  end

  defp terminated(reason, %State{channel: %Channel{} = channel}) do
    Logger.warn(
      "#{__MODULE__} stopped for #{inspect(channel)} due to #{inspect(reason)}"
    )
  end

end
