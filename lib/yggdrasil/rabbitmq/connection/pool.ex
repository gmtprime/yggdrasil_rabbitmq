defmodule Yggdrasil.RabbitMQ.Connection.Pool do
  @moduledoc """
  RabbitMQ connection pool.
  """
  use Supervisor

  alias AMQP.Channel
  alias Yggdrasil.RabbitMQ.ChannelCache
  alias Yggdrasil.RabbitMQ.Connection
  alias Yggdrasil.Settings.RabbitMQ, as: Settings

  @registry Yggdrasil.Settings.yggdrasil_process_registry!()

  @typedoc """
  Tag for the connection pool.
  """
  @type tag :: :subscriber | :publisher

  ############
  # Public API

  @doc """
  Starts a connection pool using a `tag` and a `namespace` to identify it.
  Additionally, it receives `Supervisor` `options`.
  """
  @spec start_link(tag(), Connection.namespace()) :: Supervisor.on_start()
  @spec start_link(tag(), Connection.namespace(), Supervisor.options()) ::
          Supervisor.on_start()
  def start_link(tag, namespace, options \\ [])

  def start_link(tag, namespace, options) when tag in [:subscriber, :publisher] do
    Supervisor.start_link(__MODULE__, {tag, namespace}, options)
  end

  @doc """
  Stops a RabbitMQ connection `pool`. Optionally, it receives a stop `reason`
  (defaults to `:normal`) and timeout (defaults to `:infinity`).
  """
  @spec stop(Supervisor.supervisor()) :: :ok
  @spec stop(Supervisor.supervisor(), term()) :: :ok
  @spec stop(Supervisor.supervisor(), term(), :infinity | non_neg_integer()) ::
          :ok
  defdelegate stop(pool, reason \\ :normal, timeout \\ :infinity),
    to: Supervisor

  @doc """
  Runs a `callback` with a channel for a `tag` and `namespace` for a `caller`.
  """
  @spec with_rabbitmq(
          caller :: pid(),
          tag :: tag(),
          namespace :: Connection.namespace()
        ) :: {:ok, term()} | {:error, term()}
  @spec with_rabbitmq(
          caller :: pid(),
          tag :: tag(),
          namespace :: Connection.namespace(),
          callback :: (Channel.t() -> {:ok, term()} | {:error, term()})
        ) :: {:ok, term()} | {:error, term()}
  def with_rabbitmq(caller, tag, namespace, callback \\ &{:ok, &1})

  def with_rabbitmq(
        caller,
        tag,
        namespace,
        callback
      ) when tag in [:subscriber, :publisher] do
    name = gen_pool_name(tag, namespace)

    :poolboy.transaction(name, fn worker ->
      with {:error, _} <- ChannelCache.lookup(caller, tag, namespace),
           {:ok, conn} <- Connection.get(worker),
           {:ok, chan} <- Channel.open(conn),
           :ok <- ChannelCache.insert(caller, tag, namespace, chan) do
        callback.(chan)
      else
        {:ok, %Channel{} = chan} ->
          callback.(chan)
        error ->
          error
      end
    end)
  end

  @doc """
  Opens a channel for a `tag` and `namespace` for a `caller`.
  """
  @spec open_channel(pid(), tag(), Connection.namespace()) ::
          {:ok, Channel.t()} | {:error, term()}
  def open_channel(caller, tag, namespace)

  def open_channel(
        caller,
        tag,
        namespace
      ) when tag in [:subscriber, :publisher] do
    with_rabbitmq(caller, tag, namespace)
  end

  #####################
  # Supervisor callback

  @impl true
  def init({tag, namespace}) do
    name = gen_pool_name(tag, namespace)
    size = gen_pool_size(tag, namespace)

    pool_args = [
      name: name,
      worker_module: Connection,
      size: size,
      max_overflow: size
    ]

    children = [
      :poolboy.child_spec(name, pool_args, namespace)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  #########
  # Helpers

  @doc false
  @spec gen_pool_name(tag(), Connection.namespace())
          :: {:via, module(), {tag(), Connection.namespace()}}
  def gen_pool_name(tag, namespace) do
    {:via, @registry, {tag, namespace}}
  end

  @doc false
  @spec gen_pool_size(tag(), Connection.namespace()) :: pos_integer()
  def gen_pool_size(:subscriber, namespace) do
    Settings.subscriber_connections!(namespace)
  end

  def gen_pool_size(:publisher, namespace) do
    Settings.publisher_connections!(namespace)
  end
end
