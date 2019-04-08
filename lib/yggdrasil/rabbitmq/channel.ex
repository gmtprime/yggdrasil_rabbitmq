defmodule Yggdrasil.RabbitMQ.Channel do
  @moduledoc """
  This module defines a supervised RabbitMQ channel.
  """
  use GenServer

  alias AMQP.Channel, as: RabbitChan
  alias Yggdrasil.RabbitMQ.Client

  require Logger

  ############
  # Public API

  @doc """
  Starts a supervised channel for a `client`. Optionally, you can add
  `GenServer` `options`.
  """
  @spec start_link(Client.t()) :: GenServer.on_start()
  @spec start_link(Client.t(), GenServer.options()) :: GenServer.on_start()
  def start_link(client, options \\ [])

  def start_link(client, options) do
    GenServer.start_link(__MODULE__, client, options)
  end

  @doc """
  Stops a supervised `channel`. Optionally, receives a stop `reason` (defaults
  to `:normal`) and a `timeout` in milliseconds (defaults to `:infinity`).
  """
  @spec stop(GenServer.name()) :: :ok
  @spec stop(GenServer.name(), term()) :: :ok
  @spec stop(GenServer.name(), term(), :infinity | non_neg_integer()) :: :ok
  defdelegate stop(channel, reason \\ :normal, timeout \\ :infinity),
    to: GenServer

  @doc """
  Gets the RabbitMQ channel for a supervised `channel`.
  """
  @spec get(GenServer.name()) :: {:ok, RabbitChan.t()} | {:error, term()}
  def get(channel)

  def get(channel) do
    GenServer.call(channel, :get)
  catch
    _, _ ->
      {:error, "Channel not found"}
  end

  @doc """
  Subscribes to the channel given a `client`.
  """
  @spec subscribe(Client.t()) :: :ok
  def subscribe(names)

  def subscribe(namespace) do
    Yggdrasil.subscribe(name: {__MODULE__, namespace})
  end

  #####################
  # GenServer callbacks

  @impl true
  def init(
        %Client{
          pid: client_pid,
          channel: %RabbitChan{pid: channel_pid}
        } = client
      ) do
    _ = Process.flag(:trap_exit, true)
    _ = Process.monitor(client_pid)
    _ = Process.monitor(channel_pid)
    _ = Process.link(channel_pid)
    connected(client)
    {:ok, client}
  end

  @impl true
  def handle_info({:DOWN, _, _, pid, _}, %Client{pid: pid} = client) do
    # Client dies
    {:stop, :normal, client}
  end

  def handle_info(
        {:DOWN, _, _, pid, _},
        %Client{channel: %RabbitChan{pid: pid}} = client
      ) do
    # Channel dies
    {:stop, :normal, client}
  end

  def handle_info(_, %Client{} = client) do
    {:noreply, client}
  end

  @impl true
  def handle_call(:get, _from, %Client{channel: channel} = client) do
    {:reply, {:ok, channel}, client}
  end

  @impl true
  def terminate(_, %Client{} = client) do
    close_channel(client)
    disconnected(client)
    :ok
  end

  #########
  # Helpers

  defp send_notification(%Client{namespace: namespace}, message) do
    Yggdrasil.publish([name: {__MODULE__, namespace}], message)
  end

  defp connected(%Client{} = client) do
    send_notification(client, :connected)

    Logger.debug(
      "#{__MODULE__} connected to channel for client #{inspect(client)}"
    )
  end

  defp close_channel(%Client{channel: channel} = client) do
    RabbitChan.close(channel)
    closed_channel(client)
  catch
    _, _ ->
      :ok
  end

  defp closed_channel(%Client{} = client) do
    send_notification(client, :closed_channel)
    Logger.debug("#{__MODULE__} closed channel for client #{inspect(client)}")
  end

  defp disconnected(%Client{} = client) do
    send_notification(client, :disconnected)

    Logger.debug(
      "#{__MODULE__} disconnected from channel for client #{inspect(client)}"
    )
  end
end
