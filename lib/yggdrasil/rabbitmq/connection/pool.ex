defmodule Yggdrasil.RabbitMQ.Connection.Pool do
  @moduledoc """
  RabbitMQ connection pool.
  """
  use Supervisor

  alias AMQP.Channel, as: RabbitChan
  alias Yggdrasil.RabbitMQ.Channel.Generator, as: ChannelGen
  alias Yggdrasil.RabbitMQ.Client
  alias Yggdrasil.RabbitMQ.Connection
  alias Yggdrasil.Settings.RabbitMQ, as: Settings

  @typedoc """
  Callback for running functions using RabbitMQ channels.
  """
  @type rabbit_callback ::
          (Channel.t() -> :ok | {:ok, term()} | {:error, term()})

  @registry Yggdrasil.Settings.yggdrasil_process_registry!()

  @typedoc """
  Channel callback return.
  """
  @type channel_callback_return ::
          {:ok, term()} | {:error, term()} | term()
  @typedoc """
  Channel callback function.
  """
  @type channel_callback ::
          (RabbitChan.t() -> channel_callback_return())

  ############
  # Public API

  @doc """
  Starts a connection pool using an initial `client`. Optionally, it receives
  some `Supervisor` `options`.
  """
  @spec start_link(Client.t()) :: Supervisor.on_start()
  @spec start_link(Client.t(), Supervisor.options()) :: Supervisor.on_start()
  def start_link(client, options \\ [])

  def start_link(%Client{} = client, options) do
    Supervisor.start_link(__MODULE__, client, options)
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
  Runs a channel `callback` in a `client`.
  """
  @spec with_channel(Client.t(), channel_callback()) ::
          channel_callback_return()
  def with_channel(client, callback)

  def with_channel(client, callback) do
    name = gen_pool_name(client)

    :poolboy.transaction(name, fn worker ->
      with {:error, _} <- ChannelGen.lookup(client),
           {:ok, conn} <- Connection.get(worker),
           {:ok, channel} <- ChannelGen.open(client, conn) do
        callback.(channel)
      else
        {:ok, %RabbitChan{} = channel} ->
          callback.(channel)
        error ->
          error
      end
    end)
  end

  #####################
  # Supervisor callback

  @impl true
  def init(%Client{namespace: namespace} = client) do
    name = gen_pool_name(client)
    size = gen_pool_size(client)

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

  ##
  # Generates pool name.
  defp gen_pool_name(%Client{tag: tag, namespace: namespace}) do
    {:via, @registry, {__MODULE__, tag, namespace}}
  end

  ##
  # Gets pool size.
  defp gen_pool_size(%Client{tag: :subscriber, namespace: namespace}) do
    Settings.subscriber_connections!(namespace)
  end

  defp gen_pool_size(%Client{tag: :publisher, namespace: namespace}) do
    Settings.publisher_connections!(namespace)
  end
end
