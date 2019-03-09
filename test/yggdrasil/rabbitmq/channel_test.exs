defmodule Yggdrasil.RabbitMQ.ChannelTest do
  use ExUnit.Case

  alias AMQP.Channel, as: RabbitChan
  alias Yggdrasil.RabbitMQ.Channel
  alias Yggdrasil.RabbitMQ.ChannelCache
  alias Yggdrasil.RabbitMQ.Client

  setup do
    channel = spawn fn ->
      receive do
        _ -> :ok
      end
    end

    client = %Client{
      pid: self(),
      namespace: __MODULE__,
      tag: :publisher,
      channel: %RabbitChan{pid: channel}
    }

    config = [rabbitmq: [debug: true]]
    Application.put_env(:yggdrasil, __MODULE__, config)

    {:ok, [client: client]}
  end

  describe "start/1" do
    test "inserts the new channel in cache",
           %{client: %Client{channel: channel} = client} do
      assert {:ok, _} = Channel.start_link(client)
      assert {:ok, ^channel} = ChannelCache.lookup(client)
    end
  end

  describe "on RabbitMQ failure/stop" do
    setup %{client: client} do
      :ok = Yggdrasil.subscribe(name: {Channel, __MODULE__})
      assert_receive {:Y_CONNECTED, _}
      assert {:ok, pid} = Channel.start_link(client)
      {:ok, [pid: pid]}
    end

    test "when channel dies, process dies",
           %{client: %Client{channel: channel}, pid: pid} do
      assert_receive {:Y_EVENT, _, :connected}
      Process.exit(channel.pid, :kill)
      assert_receive {:Y_EVENT, _, :disconnected}
      assert not Process.alive?(pid)
    end

    test "when process dies, channel is removed",
           %{client: %Client{channel: channel} = client} do
      assert_receive {:Y_EVENT, _, :connected}
      assert {:ok, ^channel} = ChannelCache.lookup(client)
      Process.exit(channel.pid, :kill)
      assert_receive {:Y_EVENT, _, :disconnected}
      assert {:error, _} = ChannelCache.lookup(client)
    end
  end

  describe "on client failure/exit" do
    setup %{client: client} do
      client_pid = spawn fn ->
        receive do
          _ -> :stop
        end
      end
      client = %Client{client | pid: client_pid}
      :ok = Yggdrasil.subscribe(name: {Channel, __MODULE__})
      assert_receive {:Y_CONNECTED, _}
      assert {:ok, pid} = Channel.start_link(client)
      {:ok, [pid: pid, client: client]}
    end

    test "when client dies, process dies",
           %{client: %Client{pid: client_pid}, pid: pid} do
      assert_receive {:Y_EVENT, _, :connected}
      Process.exit(client_pid, :kill)
      assert_receive {:Y_EVENT, _, :disconnected}
      assert not Process.alive?(pid)
    end

    test "when client dies, channel is closed",
           %{client: %Client{pid: client_pid, channel: channel}, pid: pid} do
      assert_receive {:Y_EVENT, _, :connected}
      Process.exit(client_pid, :kill)
      assert_receive {:Y_EVENT, _, :disconnected}
      assert not Process.alive?(pid)
      assert not Process.alive?(channel.pid)
    end
  end
end
