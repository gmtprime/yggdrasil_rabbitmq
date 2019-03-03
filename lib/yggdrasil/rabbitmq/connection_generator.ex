defmodule Yggdrasil.RabbitMQ.ConnectionGenerator do
  @moduledoc """
  This module defines a supervisor for creating connection pools on demand.
  """
  use DynamicSupervisor

  alias AMQP.Channel
  alias Yggdrasil.RabbitMQ.ChannelCache
  alias Yggdrasil.RabbitMQ.ConnectionPool, as: Pool
  alias Yggdrasil.Settings

  @cache ChannelCache.get_cache()
  @registry Settings.yggdrasil_process_registry!()

  @doc """
  Starts a connection pool generator.
  """
  @spec start_link() :: Supervisor.on_start()
  @spec start_link(DynamicSupervisor.options()) :: Supervisor.on_start()
  def start_link(options \\ []) do
    DynamicSupervisor.start_link(__MODULE__, nil, options)
  end

  @doc """
  Stops a connection pool `generator`. Optionally, it receives a `reason`
  (defaults to `:normal`) and a `timeout` (default to `:infinity`).
  """
  defdelegate stop(generator, reason \\ :normal, timeout \\ :infinity),
    to: DynamicSupervisor

  @doc """
  Opens a new channel for a `tag` and a `namespace`. Optionally, it receives
  `options`, but they are only for testing purposes:

  - `:generator` - Generator name or PID (defaults to #{__MODULE__}).
  - `:cache` - `:ets` table reference or name (default to `#{inspect @cache}`).
  - `:process` - Process name or PID that will be related to the channel (
    defaults to the caller's PID).
  """
  @spec open_channel(Pool.tag(), Pool.namespace())
          :: {:ok, term()} | {:error, term()}
  @spec open_channel(Pool.tag(), Pool.namespace(), Keyword.t())
          :: {:ok, term()} | {:error, term()}
  def open_channel(tag, namespace, options \\ [])

  def open_channel(tag, namespace, options) do
    generator = Keyword.get(options, :generator, __MODULE__)
    cache = Keyword.get(options, :cache, @cache)
    pid = Keyword.get(options, :pid, self())

    open_channel(generator, cache, pid, tag, namespace)
  end

  @doc false
  @spec open_channel(
          Supervisor.supervisor(),
          atom() | reference(),
          pid(),
          Pool.tag(),
          Pool.namespace()
        ) :: {:ok, term()} | {:error, term()}
  def open_channel(generator, cache, pid, tag, namespace) do
    with {:error, _} <- ChannelCache.lookup(cache, pid, tag, namespace),
         {:ok, _} <- connect(generator, tag, namespace),
         {:ok, conn} <- Pool.get_connection(tag, namespace),
         {:ok, chan} <- Channel.open(conn),
         :ok <- ChannelCache.insert(pid, tag, namespace, chan) do
      {:ok, chan}
    end
  end

  @doc """
  Closes a channel for a `tag` and a `namespace`. Optionally, it receives
  `options`, but they are only for testing purposes:

  - `:cache` - `:ets` table reference or name (default to `#{inspect @cache}`).
  - `:process` - Process name or PID that will be related to the channel (
    defaults to the caller's PID).
  """
  @spec close_channel(Pool.tag(), Pool.namespace()) :: :ok
  @spec close_channel(Pool.tag(), Pool.namespace(), Keyword.t()) :: :ok
  def close_channel(tag, namespace, options \\ [])

  def close_channel(tag, namespace, options) do
    cache = Keyword.get(options, :cache, @cache)
    pid = Keyword.get(options, :pid, self())

    close_channel(cache, pid, tag, namespace)
  end

  @doc false
  @spec close_channel(
          atom() | reference(),
          pid(),
          Pool.tag(),
          Pool.namespace()
        ) :: :ok
  def close_channel(cache, pid, tag, namespace) do
    with {:ok, chan} <- ChannelCache.lookup(cache, pid, tag, namespace) do
      Channel.close(chan)
    else
      _ ->
        :ok
    end
  end

  ############################
  # DynamicSupervisor callback

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  #########
  # Helpers

  @doc false
  @spec connect(Supervisor.supervisor(), Pool.tag(), Pool.namespace())
          :: DynamicSupervisor.on_start_child()
  def connect(generator, tag, namespace) do
    name = gen_pool_name(tag, namespace)

    case @registry.whereis_name(name) do
      :undefined ->
        spec = gen_pool_specs(name)
        DynamicSupervisor.start_child(generator, spec)

      pid when is_pid(pid) ->
        {:ok, pid}
    end
  end

  ##
  # Generates the pool name.
  defp gen_pool_name(tag, namespace), do: {Pool, tag, namespace}

  ##
  # Generates the pool spec.
  defp gen_pool_specs({_, tag, namespace} = name) do
    via_tuple = {:via, @registry, name}

    %{
      id: via_tuple,
      type: :supervisor,
      restart: :transient,
      start: {Pool, :start_link, [tag, namespace, [name: via_tuple]]}
    }
  end
end
