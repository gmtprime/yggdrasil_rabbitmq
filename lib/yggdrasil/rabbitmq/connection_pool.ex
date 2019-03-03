defmodule Yggdrasil.RabbitMQ.ConnectionPool do
  @moduledoc """
  RabbitMQ connection pool.
  """
  use Supervisor

  alias Yggdrasil.RabbitMQ.Connection
  alias Yggdrasil.Settings.RabbitMQ, as: Settings

  @registry Yggdrasil.Settings.yggdrasil_process_registry!()

  @typedoc """
  Tag for the connection pool.
  """
  @type tag :: :subscriber | :publisher

  @typedoc """
  Namespace.
  """
  @type namespace :: atom()

  ############
  # Public API

  @doc """
  Starts a connection pool using a `tag` and a `namespace` to identify it.
  Additionally, it receives `Supervisor` `options`.
  """
  @spec start_link(tag(), namespace()) :: Supervisor.on_start()
  @spec start_link(tag(), namespace(), Supervisor.options()) ::
          Supervisor.on_start()
  def start_link(tag, namespace, options \\ [])

  def start_link(:subscriber, namespace, options) do
    Supervisor.start_link(__MODULE__, {:subscriber, namespace}, options)
  end

  def start_link(:publisher, namespace, options) do
    Supervisor.start_link(__MODULE__, {:publisher, namespace}, options)
  end

  @doc """
  Stops a RabbitMQ connection `pool`. Optionally, it receives a stop `reason`
  (defaults to `:normal`) and timeout (defaults to `:infinity`).
  """
  defdelegate stop(pool, reason \\ :normal, timeout \\ :infinity),
    to: Supervisor

  @doc """
  Gets the an open connection with a `tag` and a `namespace`.
  """
  @spec get_connection(tag(), namespace()) :: {:ok, term()} | {:error, term()}
  def get_connection(tag, namespace)

  def get_connection(:subscriber, namespace) do
    name = gen_pool_name(:subscriber, namespace)
    :poolboy.transaction(name, &Connection.get_connection(&1))
  end

  def get_connection(:publisher, namespace) do
    name = gen_pool_name(:publisher, namespace)
    :poolboy.transaction(name, &Connection.get_connection(&1))
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
  @spec gen_pool_name(tag(), namespace())
          :: {:via, module(), {tag(), namespace()}}
  def gen_pool_name(tag, namespace) do
    {:via, @registry, {tag, namespace}}
  end

  @doc false
  @spec gen_pool_size(tag(), namespace()) :: pos_integer()
  def gen_pool_size(:subscriber, namespace) do
    Settings.subscriber_connections!(namespace)
  end

  def gen_pool_size(:publisher, namespace) do
    Settings.publisher_connections!(namespace)
  end
end
