defmodule Yggdrasil.RabbitMQ.ChannelCache do
  @moduledoc """
  This module defines a channel cache.
  """
  use GenServer

  alias AMQP.Channel
  alias Yggdrasil.RabbitMQ.Connection
  alias Yggdrasil.RabbitMQ.Connection.Pool

  require Logger

  @cache :yggdrasil_rabbitmq_channel_cache

  ############
  # Public API

  @doc """
  Starts a channel cache with some optional `GenServer` `options`.
  """
  @spec start_link() :: GenServer.on_start()
  @spec start_link(GenServer.options()) :: GenServer.on_start()
  def start_link(options \\ [])

  def start_link(options) do
    GenServer.start_link(__MODULE__, nil, options)
  end

  @doc """
  Stops a channel `cache`. Optionally, it receives a `reason` (defaults to
  `:normal`) and a timeout (defaults to `:infinity`)
  """
  @spec stop(GenServer.name()) :: :ok
  @spec stop(GenServer.name(), term()) :: :ok
  @spec stop(GenServer.name(), term(), :infinity | non_neg_integer()) :: :ok
  defdelegate stop(cache, reason \\ :normal, timeout \\ :infinity),
    to: GenServer

  @doc """
  Looks up a channel by `client` PID, `tag` and `namespace`.
  """
  @spec lookup(pid(), Pool.tag(), Connection.namespace())
          :: {:ok, term()} | {:error, term()}
  def lookup(client, tag, namespace) do
    lookup(__MODULE__, client, tag, namespace)
  end

  @doc false
  @spec lookup(GenServer.name(), pid(), Pool.tag(), Connection.namespace())
          :: {:ok, term()} | {:error, term()}
  def lookup(channel_cache, client, tag, namespace) do
    cache = :sys.get_state(channel_cache)

    do_lookup(cache, client, tag, namespace)
  end

  @doc """
  Inserts a `channel` by `client`, `tag` and `namespace`.
  """
  @spec insert(
          client :: pid(),
          tag :: Pool.tag(),
          namespace :: Connection.namespace(),
          channel :: Channel.t()
        ) :: {:ok, term()} | {:error, term()}
  def insert(client, tag, namespace, channel) do
    insert(__MODULE__, client, tag, namespace, channel)
  end

  @doc false
  @spec insert(
          channel_cache :: GenServer.name(),
          client :: pid(),
          tag :: Pool.tag(),
          namespace :: Connection.namespace(),
          channel :: Channel.t()
        ) :: {:ok, term()} | {:error, term()}
  def insert(channel_cache, client, tag, namespace, channel) do
    message = {:insert, client, tag, namespace, channel}
    GenServer.call(channel_cache, message)
  end

  #####################
  # GenServer callbacks

  @impl true
  def init(_) do
    _ = Process.flag(:trap_exit, true)
    opts = [:set, :public, read_concurrency: true]
    cache = :ets.new(@cache, opts)
    {:ok, cache}
  end

  @impl true
  def handle_call({:insert, client, tag, namespace, channel}, _from, cache) do
    do_insert(cache, client, tag, namespace, channel)
    {:reply, :ok, cache}
  end

  @impl true
  def handle_info({:DOWN, _, _, pid, _}, cache) do
    do_delete(cache, pid)
    {:noreply, cache}
  end

  def handle_info({:EXIT, _, _}, cache) do
    {:noreply, cache}
  end

  @impl true
  def terminate(:normal, cache) do
    Logger.debug("#{__MODULE__} stopped")
    do_delete_all(cache)
    :ok
  end

  def terminate(reason, cache) do
    Logger.warn("#{__MODULE__} stopped with reason #{inspect(reason)}")
    do_delete_all(cache)
    :ok
  end

  #####################
  # GenServer callbacks

  @impl true
  def init(_) do
    _ = Process.flag(:trap_exit, true)
    opts = [:set, :public, :named_table, read_concurrency: true]
    cache = :ets.new(@cache, opts)
    {:ok, cache}
  end

  @impl true
  def handle_call({:insert, {key, %Channel{pid: pid}} = pair}, _from, cache) do
    _ = Process.monitor(pid)
    :ets.insert(cache, pair)
    :ets.insert(cache, {pid, key})
    {:reply, :ok, cache}
  end

  @impl true
  def handle_info({:DOWN, _, _, pid, _}, cache) do
    case :ets.lookup(cache, pid) do
      [] ->
        {:noreply, cache}
      [{^pid, key} | _] ->
        :ets.delete(cache, pid)
        :ets.delete(cache, key)
        {:noreply, cache}
    end
  end

  #########
  # Helpers

  @chan :rabbitmq_chan
  @typedoc false
  @type chan_key :: {:rabbitmq_chan, pid(), Pool.tag(), Connection.namespace()}

  @pid :rabbitmq_pid
  @typedoc false
  @type pid_key :: {:rabbitmq_pid, pid()}

  @doc false
  # Looks up a channel by `client` PID, `tag` and `namespace` in a `cache`.
  @spec do_lookup(
          cache :: :ets.tab(),
          client :: pid(),
          tag :: Pool.tag(),
          namespace :: Connection.namespace()
        ) :: {:ok, Channel.t()} | {:error, term()}
  def do_lookup(cache, client, tag, namespace) do
    chan_key = {@chan, client, tag, namespace}

    with [{^chan_key, %Channel{} = channel} | _] <-
           :ets.lookup(cache, chan_key) do
      {:ok, channel}
    else
      _ ->
        {:error, "Channel not found"}
    end
  end

  @doc false
  # Inserts a new channel-client relation.
  @spec do_insert(
          cache :: :ets.tab(),
          client :: pid(),
          tag :: Pool.tag(),
          namespace :: Connection.namespace(),
          channel :: Channel.t()
        ) :: :ok
  def do_insert(cache, client, tag, namespace, %Channel{pid: pid} = channel) do
    with [] <- :ets.lookup(cache, {@pid, pid}) do
      _ = Process.monitor(client)
      _ = Process.monitor(pid)
      # On exit closes all channels.
      _ = Process.link(pid)
      chan_key = {@chan, client, tag, namespace}
      :ets.insert(cache, {{@pid, client}, chan_key})
      :ets.insert(cache, {{@pid, pid}, chan_key})
      :ets.insert(cache, {chan_key, channel})

      Logger.debug(
        "#{__MODULE__} opened a RabbitMQ #{inspect(tag)} channel" <>
          " namespace #{inspect(namespace)} and client #{inspect(client)}"
      )
    end

    :ok
  end

  @doc false
  # Deletes a channel-client relation.
  @spec do_delete(cache :: :ets.tab(), pid :: pid()) :: :ok
  def do_delete(cache, pid) when is_pid(pid) do
    case :ets.lookup(cache, {@pid, pid}) do
      [] ->
        :ok

      # Client died
      [{{@pid, ^pid}, {@chan, ^pid, tag, namespace} = chan_key} | _] ->
        Logger.debug(
          "#{__MODULE__} closing #{inspect(tag)} channel for" <>
            " namespace #{inspect(namespace)} and client #{inspect(pid)}"
        )

        do_delete_client(cache, chan_key)

      # Channel died
      [{{@pid, ^pid}, {@chan, client, tag, namespace} = chan_key} | _] ->
        Logger.debug(
          "#{__MODULE__} closing #{inspect(tag)} channel for" <>
            " namespace #{inspect(namespace)} and client #{inspect(client)}"
        )

        do_delete_client(cache, chan_key, {@pid, pid})
    end
  end

  @doc false
  # Deletes a channel-client relation. Closes the channel if the client is
  # dead.
  @spec do_delete_client(:ets.tab(), chan_key()) :: :ok | no_return()
  @spec do_delete_client(:ets.tab(), chan_key(), nil | pid_key()) ::
          :ok | no_return()
  def do_delete_client(cache, chan_key, client_pid_key \\ nil)

  def do_delete_client(cache, {@chan, _, _, _} = chan_key, nil) do
    with [{^chan_key, %Channel{pid: pid} = channel} | _] <-
           :ets.lookup(cache, chan_key) do
      :ok = Channel.close(channel)
      do_delete_client(cache, chan_key, {@pid, pid})
    end

    :ok
  end

  def do_delete_client(cache, {@chan, client, _, _} = chan_key, {@pid, pid}) do
    :ets.delete(cache, chan_key)
    :ets.delete(cache, {@pid, pid})
    :ets.delete(cache, {@pid, client})

    :ok
  end

  @doc false
  # Deletes all.
  @spec do_delete_all(:ets.tab()) :: :ok | no_return()
  def do_delete_all(cache) do
    cache
    |> :ets.match({{@chan, :_, :_, :_}, :"$1"})
    |> List.flatten()
    |> Enum.map(fn channel -> :ok = Channel.close(channel) end)

    :ets.delete(cache)

    :ok
  end
end
