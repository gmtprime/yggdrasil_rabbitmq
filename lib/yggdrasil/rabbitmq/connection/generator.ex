defmodule Yggdrasil.RabbitMQ.Connection.Generator do
  @moduledoc """
  This module defines a supervisor for creating connection pools on demand.
  """
  use DynamicSupervisor

  alias Yggdrasil.RabbitMQ.Client
  alias Yggdrasil.RabbitMQ.Connection.Pool

  @doc """
  Starts a connection pool generator.
  """
  @spec start_link() :: Supervisor.on_start()
  @spec start_link([
          DynamicSupervisor.option() | DynamicSupervisor.init_option()
        ]) :: Supervisor.on_start()
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
  Runs a channel `callback` in a `client`.
  """
  @spec with_channel(Client.t()) :: Pool.channel_callback_return()
  @spec with_channel(Client.t(), Pool.channel_callback()) ::
          Pool.channel_callback_return()
  def with_channel(client, callback \\ &{:ok, &1})

  def with_channel(client, callback) do
    case connect(__MODULE__, client) do
      {:ok, _} ->
        Pool.with_channel(client, callback)

      {:error, {:already_started, _}} ->
        Pool.with_channel(client, callback)

      error ->
        error
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
  @spec connect(Supervisor.supervisor(), Client.t()) ::
          DynamicSupervisor.on_start_child()
  def connect(generator, client)

  def connect(generator, %Client{} = client) do
    name = gen_pool_name(client)

    case ExReg.whereis_name(name) do
      :undefined ->
        specs = gen_pool_specs(name, client)
        DynamicSupervisor.start_child(generator, specs)

      pid when is_pid(pid) ->
        {:ok, pid}
    end
  end

  ##
  # Generates the pool name.
  defp gen_pool_name(%Client{tag: tag, namespace: namespace}) do
    {__MODULE__, tag, namespace}
  end

  ##
  # Generates the pool spec.
  defp gen_pool_specs(name, %Client{} = client) do
    via_tuple = ExReg.local(name)

    %{
      id: via_tuple,
      type: :supervisor,
      restart: :transient,
      start: {Pool, :start_link, [client, [name: via_tuple]]}
    }
  end
end
