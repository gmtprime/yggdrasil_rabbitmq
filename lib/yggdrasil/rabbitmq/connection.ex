defmodule Yggdrasil.RabbitMQ.Connection do
  @moduledoc """
  This module defines RabbitMQ generalizations.
  """
  use Bitwise

  require Logger

  alias AMQP.Channel, as: Chan
  alias AMQP.Connection, as: Conn
  alias Yggdrasil.Settings.RabbitMQ, as: Settings

  @doc false
  defstruct namespace: nil,
            conn: nil,
            chan: nil,
            retries: 0,
            backoff: 0

  alias __MODULE__, as: State

  @typedoc false
  @type t :: %State{
          namespace: namespace :: atom(),
          conn: connection :: term(),
          chan: channel :: term(),
          retries: retries :: non_neg_integer(),
          backoff: backoff :: non_neg_integer()
        }

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
      with {:ok, conn} <- Conn.open(options),
           {:ok, chan} <- Chan.open(conn) do
        _ = Process.monitor(conn.pid)
        _ = Process.monitor(chan.pid)
        state = %State{namespace: namespace, conn: conn, chan: chan}
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
      host: Settings.yggdrasil_rabbitmq_hostname!(namespace),
      port: Settings.yggdrasil_rabbitmq_port!(namespace),
      username: Settings.yggdrasil_rabbitmq_username!(namespace),
      password: Settings.yggdrasil_rabbitmq_password!(namespace),
      virtual_host: Settings.yggdrasil_rabbitmq_virtual_host!(namespace),
      heartbeat: Settings.yggdrasil_rabbitmq_heartbeat!(namespace)
    ]
  end

  @doc """
  Calculates the backoff given an `error` and a  `state`.
  """
  @spec backoff(term(), State.t()) :: State.t()
  def backoff(error, state)

  def backoff(error, %State{namespace: namespace, retries: retries} = state) do
    max_retries = Settings.yggdrasil_rabbitmq_max_retries!(namespace)
    slot_size = Settings.yggdrasil_rabbitmq_slot_size!(namespace)

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

  def disconnect(:normal, %State{conn: conn, chan: chan} = state) do
    if Process.alive?(chan.pid), do: :ok = AMQP.Channel.close(chan)
    if Process.alive?(conn.pid), do: :ok = AMQP.Connection.close(conn)
    new_state = %State{state | conn: nil, chan: nil}
    disconnected(:normal, new_state)
    new_state
  end

  def disconnect(reason, %State{conn: conn, chan: chan} = state) do
    if Process.alive?(chan.pid), do: :ok = GenServer.stop(chan.pid)
    if Process.alive?(conn.pid), do: :ok = AMQP.Connection.close(conn)
    new_state = %State{state | conn: nil, chan: nil}
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
