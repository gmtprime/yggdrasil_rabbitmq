defmodule Yggdrasil.RabbitMQ.Connection do
  @moduledoc """
  This module defines a RabbitMQ connection process.
  """
  use GenServer
  use Bitwise

  require Logger

  alias AMQP.Connection
  alias Yggdrasil.Settings.RabbitMQ, as: Settings

  @doc false
  defstruct namespace: nil,
            conn: nil,
            retries: 0,
            backoff: 0

  alias __MODULE__, as: State

  @typedoc false
  @type t :: %State{
          namespace: namespace :: atom(),
          conn: connection :: term(),
          retries: retries :: non_neg_integer(),
          backoff: backoff :: non_neg_integer()
        }

  ############
  # Client API

  @doc """
  Starts a RabbitMQ connection with a `namespace` for the configuration.
  Additionally, you can add `GenServer` `options`.
  """
  @spec start_link(term()) :: GenServer.on_start()
  @spec start_link(term(), GenServer.options()) :: GenServer.on_start()
  @impl true
  def start_link(namespace, options \\ [])

  def start_link(namespace, options) do
    GenServer.start_link(__MODULE__, namespace, options)
  end

  @doc """
  Stops a RabbitMQ `connection`. Optionally, receives a stop `reason` (defaults
  to `:normal`) and a `timeout` in milliseconds (defaults to `:infinity`).
  """
  @spec stop(GenServer.name()) :: :ok
  @spec stop(GenServer.name(), term()) :: :ok
  @spec stop(GenServer.name(), term(), pos_integer() | :infinity) :: :ok
  defdelegate stop(connection, reason \\ :normal, timeout \\ :infinity),
    to: GenServer

  @doc """
  Gets connection struct from a `connection` process.
  """
  @spec get_connection(GenServer.name()) :: {:ok, term()} | {:error, term()}
  def get_conection(connection)

  def get_connection(connection) do
    GenServer.call(connection, :get)
  end

  #####################
  # GenServer callbacks

  @impl true
  def init(namespace) do
    Process.flag(:trap_exit, true)
    state = %State{namespace: namespace}
    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, %State{} = state) do
    with {:ok, new_state} <- connect(state) do
      {:noreply, new_state}
    else
      error ->
        {:noreply, state, {:continue, {:backoff, error}}}
    end
  end

  def handle_continue({:backoff, error}, %State{} = state) do
    new_state = backoff(error, state)
    {:noreply, new_state}
  end

  def handle_continue({:disconnect, _}, %State{conn: nil} = state) do
    {:noreply, state}
  end

  def handle_continue({:disconnect, reason}, %State{} = state)
      when reason != :normal do
    new_state = disconnect(reason, state)
    {:noreply, new_state, {:continue, {:backoff, reason}}}
  end

  @impl true
  def handle_info({:timeout, continue}, %State{} = state) do
    {:noreply, state, continue}
  end

  def handle_info({:DOWN, _, :process, _, reason}, %State{} = state)
      when reason != :normal do
    {:noreply, state, {:continue, {:disconnect, reason}}}
  end

  def handle_info({:EXIT, _, reason}, %State{} = state)
      when reason != :normal do
    {:noreply, state, {:continue, {:disconnect, reason}}}
  end

  def handle_info(_, %State{} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_call(:get, _from, %State{conn: nil} = state) do
    {:reply, {:error, "Not connected"}, state}
  end

  def handle_call(:get, _from, %State{conn: conn} = state) do
    {:reply, {:ok, conn}, state}
  end

  @impl true
  def terminate(:normal, %State{} = state) do
    disconnect(:normal, state)
    :ok
  end

  def terminate(reason, %State{} = state) do
    disconnect(reason, state)
    :ok
  end

  ############################
  # Connection related helpers

  @doc """
  Connects to RabbitMQ given a initial `state`.
  """
  @spec connect(State.t()) :: {:ok, State.t()} | {:error, term()}
  def connect(state)

  def connect(%State{namespace: namespace} = initial_state) do
    options = rabbitmq_options(initial_state)

    try do
      with {:ok, conn} <- Connection.open(options) do
        _ = Process.monitor(conn.pid)
        state = %State{namespace: namespace, conn: conn}
        connected(state)
        {:ok, state}
      end
    catch
      _, reason ->
        {:error, reason}
    end
  end

  @doc """
  Returns a list of RabbitMQ options given an initial `state`.
  """
  @spec rabbitmq_options(State.t()) :: Keyword.t()
  def rabbitmq_options(state)

  def rabbitmq_options(%State{namespace: namespace}) do
    [
      host: Settings.hostname!(namespace),
      port: Settings.port!(namespace),
      username: Settings.username!(namespace),
      password: Settings.password!(namespace),
      virtual_host: Settings.virtual_host!(namespace),
      heartbeat: Settings.heartbeat!(namespace)
    ]
  end

  @doc """
  Calculates the backoff given an `error` and a  `state`.
  """
  @spec backoff(term(), State.t()) :: State.t()
  def backoff(error, state)

  def backoff(error, %State{namespace: namespace, retries: retries} = state) do
    max_retries = Settings.max_retries!(namespace)
    slot_size = Settings.slot_size!(namespace)

    new_backoff = (2 <<< retries) * Enum.random(1..slot_size) * 1000
    Process.send_after(self(), {:timeout, {:continue, :connect}}, new_backoff)

    new_retries = if retries == max_retries, do: retries, else: retries + 1
    new_state = %State{state | retries: new_retries, backoff: new_backoff}
    backing_off(error, new_state)
    new_state
  end

  @doc """
  Disconnects from RabbitMQ closing the connections in the `state` with a
  `reason`.
  """
  @spec disconnect(term(), State.t()) :: State.t()
  def disconnect(reason, state)

  def disconnect(reason, %State{conn: nil} = state) do
    disconnected(reason, state)
    state
  end

  def disconnect(reason, %State{conn: %{pid: pid} = conn} = state) do
    if is_pid(pid) and Process.alive?(pid), do: :ok = Connection.close(conn)
    new_state = %State{state | conn: nil}
    disconnected(reason, new_state)
    new_state
  end

  #########################
  # Logging related helpers

  ##
  # Shows a message for a successful connection.
  @spec connected(State.t()) :: :ok
  defp connected(state)

  defp connected(%State{namespace: nil}) do
    Logger.debug("#{__MODULE__} connected to RabbitMQ")
  end

  defp connected(%State{namespace: namespace}) do
    Logger.debug(
      "#{__MODULE__} connected to RabbitMQ using namespace #{namespace}"
    )
  end

  ##
  # Shows a message when backing off.
  @spec backing_off(term(), State.t()) :: :ok
  defp backing_off(error, state)

  defp backing_off(error, %State{
         namespace: nil,
         retries: retries,
         backoff: backoff
       }) do
    Logger.warn(
      "#{__MODULE__} cannot connected to RabbitMQ" <>
        " with error #{inspect(error)}" <>
        " #{inspect(retries: retries, backoff: backoff)}"
    )
  end

  defp backing_off(
         error,
         %State{namespace: namespace, retries: retries, backoff: backoff}
       ) do
    Logger.warn(
      "#{__MODULE__} cannot connected to RabbitMQ using #{namespace}" <>
        " with error #{inspect(error)}" <>
        " #{inspect(retries: retries, backoff: backoff)}"
    )
  end

  ##
  # Shows a message on disconnection
  @spec disconnected(term(), State.t()) :: :ok
  defp disconnected(reason, state)

  defp disconnected(:normal, %State{namespace: nil}) do
    Logger.debug("#{__MODULE__} disconnected from RabbitMQ")
  end

  defp disconnected(:normal, %State{namespace: namespace}) do
    Logger.debug(
      "#{__MODULE__} disconnected from RabbitMQ using namespace #{namespace}"
    )
  end

  defp disconnected(_, %State{namespace: nil}) do
    Logger.warn("#{__MODULE__} disconnected from RabbitMQ")
  end

  defp disconnected(_, %State{namespace: namespace}) do
    Logger.warn(
      "#{__MODULE__} disconnected from RabbitMQ using namespace #{namespace}"
    )
  end
end
