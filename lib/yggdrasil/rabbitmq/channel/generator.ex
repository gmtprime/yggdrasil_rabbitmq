defmodule Yggdrasil.RabbitMQ.Channel.Generator do
  @moduledoc """
  This module defines a supervisor for creating channels on demand.
  """
  use DynamicSupervisor

  alias AMQP.Channel, as: RabbitChan
  alias AMQP.Connection, as: RabbitConn
  alias Yggdrasil.RabbitMQ.Channel
  alias Yggdrasil.RabbitMQ.Client
  alias Yggdrasil.Settings

  @registry Settings.yggdrasil_process_registry!()

  @doc """
  Starts a chanel generator.
  """
  @spec start_link() :: Supervisor.on_start()
  @spec start_link(DynamicSupervisor.options()) :: Supervisor.on_start()
  def start_link(options \\ []) do
    DynamicSupervisor.start_link(__MODULE__, nil, options)
  end

  @doc """
  Stops a channel `generator`. Optionally, it receives a `reason`
  (defaults to `:normal`) and a `timeout` (default to `:infinity`).
  """
  @spec stop(Supervisor.supervisor()) :: :ok
  @spec stop(Supervisor.supervisor(), term()) :: :ok
  @spec stop(Supervisor.supervisor(), term(), :infinity | non_neg_integer()) ::
          :ok
  defdelegate stop(generator, reason \\ :normal, timeout \\ :infinity),
    to: DynamicSupervisor

  @doc """
  Runs a supervised RabbitMQ channel for a `client` using a RabbitMQ
  `connection`.
  """
  @spec open(Client.t(), RabbitConn.t()) ::
          {:ok, RabbitChan.t()} | {:error, term()}
  def open(client, connection)

  def open(client, connection) do
    with {:ok, channel} <- RabbitChan.open(connection),
         new_client = %Client{client | channel: channel},
         {:ok, _} <- connect(__MODULE__, new_client) do
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
  @spec connect(Supervisor.supervisor(), Client.t())
          :: DynamicSupervisor.on_start_child()
  def connect(generator, client)

  def connect(generator, %Client{} = client) do
    name = gen_channel_name(client)

    case @registry.whereis_name(name) do
      :undefined ->
        specs = gen_channel_specs(name, client)
        DynamicSupervisor.start_child(generator, specs)

      pid when is_pid(pid) ->
        {:ok, pid}
    end
  end

  ##
  # Generates the pool name.
  defp gen_channel_name(%Client{tag: tag, namespace: namespace, pid: pid}) do
    {Channel, pid, tag, namespace}
  end

  ##
  # Generates the pool spec.
  defp gen_channel_specs(name, %Client{} = client) do
    via_tuple = {:via, @registry, name}

    %{
      id: via_tuple,
      type: :worker,
      restart: :temporary,
      start: {Channel, :start_link, [client, [name: via_tuple]]}
    }
  end
end
