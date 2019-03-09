defmodule Yggdrasil.RabbitMQ.Channel do
  @moduledoc """
  This module defines a supervised RabbitMQ channel.
  """
  use GenServer

  alias AMQP.Channel, as: RabbitChan
  alias Yggdrasil.RabbitMQ.ChannelCache
  alias Yggdrasil.RabbitMQ.Client
  alias Yggdrasil.Settings.RabbitMQ, as: Settings

  require Logger

  ############
  # Public API

  @doc """
  Starts a RabbitMQ connection with a `namespace` for the configuration.
  Additionally, you can add `GenServer` `options`.
  """
  @spec start_link(Client.t()) :: GenServer.on_start()
  @spec start_link(Client.t(), GenServer.options()) :: GenServer.on_start()
  def start_link(client, options \\ [])

  def start_link(client, options) do
    ChannelCache.insert(client)
    GenServer.start_link(__MODULE__, client, options)
  end

  @doc """
  Stops a RabbitMQ `connection`. Optionally, receives a stop `reason` (defaults
  to `:normal`) and a `timeout` in milliseconds (defaults to `:infinity`).
  """
  @spec stop(GenServer.name()) :: :ok
  @spec stop(GenServer.name(), term()) :: :ok
  @spec stop(GenServer.name(), term(), :infinity | non_neg_integer()) :: :ok
  defdelegate stop(connection, reason \\ :normal, timeout \\ :infinity),
    to: GenServer

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
        %Client{pid: client_pid, channel: %RabbitChan{pid: pid}} = client
  ) do
    # Channel dies
    {:stop, :normal, client}
  end

  def handle_info(_, %Client{} = client) do
    {:noreply, client}
  end

  @impl true
  def terminate(_, %Client{} = client) do
    close_channel(client)
    disconnected(client)
    :ok
  end

  #########
  # Helpers

  defp send_debug(%Client{namespace: namespace}, message) do
    if Settings.debug!(namespace) do
      Yggdrasil.publish([name: {__MODULE__, namespace}], message)
    end
  end

  defp connected(%Client{} = client) do
    send_debug(client, :connected)
    Logger.debug(
      "#{__MODULE__} connected to channel for client #{inspect client}"
    )
  end

  defp close_channel(%Client{channel: channel} = client) do
    try do
      RabbitChan.close(channel)
      closed_channel(client)
    catch
      _, _ ->
        :ok
    end
    ChannelCache.delete(client)
  end

  defp closed_channel(%Client{} = client) do
    send_debug(client, :closed)
    Logger.debug(
      "#{__MODULE__} closed channel for client #{inspect client}"
    )
  end

  defp disconnected(%Client{} = client) do
    send_debug(client, :disconnected)
    Logger.debug(
      "#{__MODULE__} disconnected from channel for client #{inspect client}"
    )
  end
end
