defmodule Yggdrasil.RabbitMQ.ChannelCache do
  @moduledoc """
  This module defines a channel cache.
  """
  use GenServer

  alias AMQP.Channel

  @cache :yggdrasil_rabbitmq_channel_cache

  @doc """
  Returns the cache name.
  """
  @spec get_cache() :: atom()
  def get_cache, do: @cache

  @doc """
  Starts a channel cache with some optional `GenServer` `options`.
  """
  @spec start_link() :: GenServer.on_start()
  @spec start_link(GenServer.options()) :: GenServer.on_start()
  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, nil, options)
  end

  @doc """
  Stops a channel `cache`. Optionally, it receives a `reason` (defaults to
  `:normal`) and a timeout (defaults to `:infinity`)
  """
  defdelegate stop(cache, reason \\ :normal, timeout \\ :infinity),
    to: GenServer

  @doc """
  Looks up a channel by `pid`, `tag` and `namespace`.
  """
  @spec lookup(pid(), Pool.tag(), Pool.namespace())
          :: {:ok, term()} | {:error, term()}
  def lookup(pid, tag, namespace) do
    cache = get_cache()

    lookup(cache, pid, tag, namespace)
  end

  @doc false
  @spec lookup(atom() | reference(), pid(), Pool.tag(), Pool.namespace())
          :: {:ok, term()} | {:error, term()}
  def lookup(cache, pid, tag, namespace) do
    key = {pid, tag, namespace}

    case :ets.lookup(cache, key) do
      [] ->
        {:error, "Channel not found"}
      [{^key, channel} | _] ->
        {:ok, channel}
    end
  end

  @doc """
  Inserts a `channel` by `pid`, `tag` and `namespace`.
  """
  @spec insert(pid(), Pool.tag(), Pool.namespace(), term())
          :: {:ok, term()} | {:error, term()}
  def insert(pid, tag, namespace, channel) do
    cache = get_cache()

    insert(__MODULE__, cache, pid, tag, namespace, channel)
  end

  @doc false
  @spec insert(
          GenServer.name(),
          atom() | reference(),
          pid(),
          Pool.tag(),
          Pool.namespace(),
          term()
        ) :: :ok | {:error, term()}
  def insert(server, cache, pid, tag, namespace, channel) do
    with {:error, _} <- lookup(cache, pid, tag, namespace) do
      key = {pid, tag, namespace}
      GenServer.call(server, {:insert, {key, channel}})
    else
      _ ->
        :ok
    end
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
end
