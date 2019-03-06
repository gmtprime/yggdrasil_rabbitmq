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
  Runs a `callback` that receives a RabbitMQ channel from a `tag` and
  `namespace`. The default callback only returns an `:ok` tuple with the
  RabbitMQ channel. Optionally, it receives a new `callback` and a list of
  `options`:
  - `:caller` - PID of the calling process.
  """
  @spec with_channel(Pool.tag(), Connection.namespace()) ::
          :ok | {:ok, term()} | {:error, term()}
  @spec with_channel(
          Pool.tag(),
          Connection.namespace(),
          Pool.rabbit_callback()
        ) :: :ok | {:ok, term()} | {:error, term()}
  @spec with_channel(
          Pool.tag(),
          Connection.namespace(),
          Pool.rabbit_callback(),
          Keyword.t()
        ) :: :ok | {:ok, term()} | {:error, term()}
  def with_channel(tag, namespace, callback \\ &{:ok, &1}, options \\ [])

  def with_channel(tag, namespace, callback, options) do
    caller = Keyword.get(options, :caller, self())

    with {:ok, _} <- connect(__MODULE__, tag, namespace) do
      Pool.with_channel(caller, tag, namespace, callback)
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
