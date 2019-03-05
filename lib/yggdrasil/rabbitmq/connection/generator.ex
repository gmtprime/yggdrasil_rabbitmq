defmodule Yggdrasil.RabbitMQ.Connection.Generator do
  @moduledoc """
  This module defines a supervisor for creating connection pools on demand.
  """
  use DynamicSupervisor

  alias AMQP.Channel
  alias Yggdrasil.RabbitMQ.ChannelCache
  alias Yggdrasil.RabbitMQ.Connection
  alias Yggdrasil.RabbitMQ.Connection.Pool
  alias Yggdrasil.Settings

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
  @spec stop(Supervisor.supervisor()) :: :ok
  @spec stop(Supervisor.supervisor(), term()) :: :ok
  @spec stop(Supervisor.supervisor(), term(), :infinity | non_neg_integer()) ::
          :ok
  defdelegate stop(generator, reason \\ :normal, timeout \\ :infinity),
    to: DynamicSupervisor

  @doc """
  Opens a channel for a `tag` and a `namespace`. Optionally, it receives
  `options` e.g::
  - `:caller` - PID of the calling process.
  """
  @spec open_channel(Pool.tag(), Connection.namespace())
          :: {:ok, Channel.t()} | {:error, term()}
  @spec open_channel(Pool.tag(), Connection.namespace(), Keyword.t())
          :: {:ok, Channel.t()} | {:error, term()}
  def open_channel(tag, namespace, options \\ [])

  def open_channel(tag, namespace, options) do
    client = Keyword.get(options, :caller, self())

    with {:error, _} <- ChannelCache.lookup(client, tag, namespace),
         {:ok, _} <- connect(__MODULE__, tag, namespace),
         {:ok, %Channel{} = channel} <- Pool.open_channel(tag, namespace),
         :ok <- ChannelCache.insert(client, tag, namespace, channel) do
      {:ok, channel}
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
        specs = gen_pool_specs(name)
        DynamicSupervisor.start_child(generator, specs)

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
