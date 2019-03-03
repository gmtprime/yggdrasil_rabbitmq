defmodule Yggdrasil.Subscriber.Adapter.RabbitMQ.Connection do
  @moduledoc """
  This module defines a RabbitMQ connection handler. It does not connect until
  a process request a connection.
  """
  use Bitwise
  # use Connection

  require Logger

  alias Yggdrasil.Settings.RabbitMQ, as: Settings

  alias AMQP.Connection, as: Conn

  defstruct [:namespace, :conn, :backoff, :retries]
  alias __MODULE__, as: State

  ############
  # Public API

  @doc """
  Starts a RabbitMQ connection handler with a `namespace` to get the options
  to connect to RabbitMQ. Additionally, `GenServer` `options` can be provided.
  """
  def start_link(namespace, options \\ []) do
    state = %State{namespace: namespace, retries: 0}
    Connection.start_link(__MODULE__, state, options)
  end

  @doc """
  Stops the RabbitMQ connection handler with its `pid` with an optional
  `reason`.
  """
  def stop(pid, reason \\ :normal) do
    GenServer.stop(pid, reason)
  end

  @doc """
  Gets the RabbitMQ connection from the process identified by a `pid`.
  """
  def get_connection(pid) do
    Connection.call(pid, :get)
  end

  ######################
  # Connection callbacks

  @impl true
  def init(%State{} = state) do
    Process.flag(:trap_exit, true)
    {:connect, :init, state}
  end

  @impl true
  def connect(_, %State{namespace: namespace, conn: nil} = state) do
    options = rabbitmq_options(namespace)

    try do
      with {:ok, conn} <- Conn.open(options) do
        Process.monitor(conn.pid)

        Logger.debug(fn ->
          "#{__MODULE__} opened a connection with RabbitMQ" <>
            " #{inspect(namespace)}"
        end)

        new_state = %State{state | conn: conn, retries: 0, backoff: nil}
        {:ok, new_state}
      else
        error ->
          backoff(error, state)
      end
    catch
      :error, reason ->
        backoff({:error, reason}, state)

      error, reason ->
        backoff({:error, {error, reason}}, state)
    end
  end

  @impl true
  def disconnect(_, %State{conn: nil} = state) do
    disconnected(state)
  end

  def disconnect(info, %State{conn: conn} = state) do
    Conn.close(conn)
    disconnect(info, %State{state | conn: nil})
  end

  @impl true
  def handle_call(_, _from, %State{conn: nil, backoff: until} = state) do
    new_backoff = until - :os.system_time(:millisecond)
    new_backoff = if new_backoff < 0, do: 0, else: new_backoff
    {:reply, {:backoff, new_backoff}, state}
  end

  def handle_call(:get, _from, %State{conn: conn} = state) do
    {:reply, {:ok, conn}, state}
  end

  def handle_call(_msg, _from, %State{} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _, _, pid, _}, %State{conn: %{pid: pid}} = state) do
    new_state = %State{state | conn: nil}
    {:disconnect, :down, new_state}
  end

  def handle_info({:EXIT, pid, _}, %State{conn: %{pid: pid}} = state) do
    new_state = %State{state | conn: nil}
    {:disconnect, :exit, new_state}
  end

  def handle_info(_msg, %State{} = state) do
    {:noreply, state}
  end

  @impl true
  def terminate(reason, %State{conn: nil} = state) do
    terminated(reason, state)
  end

  def terminate(reason, %State{conn: conn} = state) do
    Conn.close(conn)
    terminate(reason, %State{state | conn: nil})
  end

  ################
  # Config helpers

  @doc false
  def rabbitmq_options(namespace) do
    [
      host: Settings.yggdrasil_rabbitmq_hostname!(namespace),
      port: Settings.yggdrasil_rabbitmq_port!(namespace),
      username: Settings.yggdrasil_rabbitmq_username!(namespace),
      password: Settings.yggdrasil_rabbitmq_password!(namespace),
      virtual_host: Settings.yggdrasil_rabbitmq_virtual_host!(namespace),
      heartbeat: Settings.yggdrasil_rabbitmq_heartbeat!(namespace)
    ]
  end

  #########
  # Helpers

  @doc false
  def calculate_backoff(%State{namespace: namespace, retries: retries} = state) do
    max_retries = Settings.yggdrasil_rabbitmq_max_retries!(namespace)
    new_retries = if retries == max_retries, do: retries, else: retries + 1

    slot_size = Settings.yggdrasil_rabbitmq_slot_size!(namespace)
    # ms
    new_backoff = (2 <<< new_retries) * Enum.random(1..slot_size)

    until = :os.system_time(:millisecond) + new_backoff
    new_state = %State{state | backoff: until, retries: new_retries}

    {new_backoff, new_state}
  end

  @doc false
  def backoff(error, %State{namespace: namespace} = state) do
    {new_backoff, new_state} = calculate_backoff(state)

    Logger.warn(fn ->
      "#{__MODULE__} cannot open connection to RabbitMQ" <>
        " for #{inspect(namespace)} due to #{inspect(error)}"
    end)

    {:backoff, new_backoff, new_state}
  end

  @doc false
  def disconnected(%State{namespace: namespace} = state) do
    Logger.warn(fn ->
      "#{__MODULE__} disconnected from RabbitMQ for #{inspect(namespace)}"
    end)

    backoff(:disconnected, state)
  end

  @doc false
  def terminated(:normal, %State{namespace: namespace}) do
    Logger.debug(fn ->
      "Stopped #{__MODULE__} for #{inspect(namespace)}"
    end)
  end

  def terminated(reason, %State{namespace: namespace}) do
    Logger.warn(fn ->
      "Stopped #{__MODULE__} for #{inspect(namespace)}" <>
        " due to #{inspect(reason)}"
    end)
  end
end
