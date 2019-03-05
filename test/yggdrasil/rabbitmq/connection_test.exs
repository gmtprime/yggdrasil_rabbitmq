defmodule Yggdrasil.RabbitMQ.ConnectionTest do
  use ExUnit.Case

  alias Yggdrasil.RabbitMQ.Connection

  setup do
    namespace = __MODULE__.Unreachable
    config = [rabbitmq: [hostname: "unreachable", debug: true]]
    Application.put_env(:yggdrasil, namespace, config)

    {:ok, [namespace: namespace]}
  end

  describe "when RabbitMQ is unreachable" do
    setup %{namespace: namespace} do
      assert :ok = Yggdrasil.subscribe(name: {Connection, namespace})
      assert_receive {:Y_CONNECTED, _}
      assert {:ok, conn} = Connection.start_link(namespace)
      assert_receive {:Y_EVENT, _, :backing_off}
      {:ok, [namespace: namespace, conn: conn]}
    end

    test "connection in state is nil", %{conn: conn} do
      assert %Connection{} = state = :sys.get_state(conn)
      assert is_nil(state.conn)
    end

    test "namespace is set", %{namespace: namespace, conn: conn} do
      assert %Connection{} = state = :sys.get_state(conn)
      assert state.namespace == namespace
    end

    test "backoff is greater than zero", %{conn: conn} do
      assert %Connection{} = state = :sys.get_state(conn)
      assert state.backoff > 0
    end

    test "retries are greater than zero", %{conn: conn} do
      assert %Connection{} = state = :sys.get_state(conn)
      assert state.retries > 0
    end
  end

  describe "when RabbitMQ is reachable" do
    setup do
      assert {:ok, conn} = Connection.start_link(nil)

      {:ok, [conn: conn]}
    end

    test "backoff is greater zero", %{conn: conn} do
      assert %Connection{} = state = :sys.get_state(conn)
      assert state.backoff == 0
    end

    test "retries are zero", %{conn: conn} do
      assert %Connection{} = state = :sys.get_state(conn)
      assert state.retries == 0
    end
  end

  describe "get/1" do
    test "cannot get connection", %{namespace: namespace} do
      assert {:ok, conn} = Connection.start_link(namespace)
      assert {:error, _} = Connection.get(conn)
    end

    test "when reachable, can get connection" do
      assert {:ok, conn} = Connection.start_link(nil)
      assert {:ok, %AMQP.Connection{} = conn} = Connection.get(conn)
      assert is_pid(conn.pid) and Process.alive?(conn.pid)
    end
  end

  describe "rabbitmq_options/1" do
    test "all parameters are defined" do
      parameters = Connection.rabbitmq_options(%Connection{})
      expected = [:host, :port, :username, :password, :virtual_host, :heartbeat]
      assert [] == expected -- Keyword.keys(parameters)
      assert [] == Keyword.keys(parameters) -- expected
    end
  end

  describe "connect/1" do
    test "when is unreachable, errors", %{namespace: namespace} do
      state = %Connection{namespace: namespace}
      assert {:error, _} = Connection.connect(state)
    end

    test "when reachable, returns new state with connection" do
      assert {:ok, state} = Connection.connect(%Connection{})
      assert Process.alive?(state.conn.pid)
    end
  end

  describe "backoff/2" do
    test "calculates new backoff" do
      assert state = Connection.backoff(:error, %Connection{})
      assert 20_000 >= state.backoff and state.backoff >= 2_000
    end

    test "calculates new retries" do
      assert state = Connection.backoff(:error, %Connection{})
      assert state.retries == 1
    end
  end

  describe "disconnect/2" do
    setup do
      {:ok, state} = Connection.connect(%Connection{})
      {:ok, [state: state]}
    end

    test "sets the connection to nil", %{state: state} do
      assert %Connection{conn: nil} = Connection.disconnect(:error, state)
    end

    test "terminates the connection", %{state: %{conn: conn} = state} do
      Process.monitor(conn.pid)
      assert %Connection{conn: nil} = Connection.disconnect(:error, state)
      assert_receive {:DOWN, _, _, _, _}
    end
  end
end
