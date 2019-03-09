defmodule Yggdrasil.RabbitMQ.ChannelCacheTest do
  use ExUnit.Case

  alias AMQP.Channel
  alias Yggdrasil.RabbitMQ.ChannelCache
  alias Yggdrasil.RabbitMQ.Client

  setup do
    channel = spawn fn ->
      receive do
        _ -> :ok
      end
    end

    cache = :ets.new(__MODULE__, [:set, :public])
    client = %Client{
      pid: self(),
      namespace: __MODULE__,
      tag: :publisher,
      channel: %Channel{pid: channel}
    }

    config = [rabbitmq: [debug: true]]
    Application.put_env(:yggdrasil, __MODULE__, config)

    {:ok, [cache: cache, client: client]}
  end

  describe "lookup/2" do
    test "when channel does not exist, errors",
           %{cache: cache, client: client} do
      assert {:error, _} = ChannelCache.lookup(cache, client)
    end

    test "when channel is dead, errors",
           %{cache: cache, client: %Client{channel: channel} = client} do
      assert :ok = ChannelCache.insert(cache, client)
      assert {:ok, ^channel} = ChannelCache.lookup(cache, client)
      Process.exit(channel.pid, :kill)
      assert {:error, _} = ChannelCache.lookup(cache, client)
    end

    test "when channel exists, returns it",
           %{cache: cache, client: %Client{channel: channel} = client} do
      assert :ok = ChannelCache.insert(cache, client)
      assert {:ok, ^channel} = ChannelCache.lookup(cache, client)
    end
  end

  describe "insert/2" do
    test "when channel is alive, inserts it",
           %{cache: cache, client: %Client{channel: channel} = client} do
      assert :ok = ChannelCache.insert(cache, client)
      assert {:ok, ^channel} = ChannelCache.lookup(cache, client)
    end

    test "when channel is dead, does not insert it",
           %{cache: cache, client: %Client{channel: channel} = client} do
      Process.exit(channel.pid, :kill)
      assert :ok = ChannelCache.insert(cache, client)
      assert {:error, _} = ChannelCache.lookup(cache, client)
    end
  end

  describe "delete/2" do
    test "when channel exists, deletes it",
           %{cache: cache, client: %Client{channel: channel} = client} do
      assert :ok = ChannelCache.insert(cache, client)
      assert {:ok, ^channel} = ChannelCache.lookup(cache, client)
      assert :ok = ChannelCache.delete(cache, client)
      assert {:error, _} = ChannelCache.lookup(cache, client)
    end

    test "when channel does not exits, succeeds",
           %{cache: cache, client: client} do
      assert :ok = ChannelCache.delete(cache, client)
      assert {:error, _} = ChannelCache.lookup(cache, client)
    end
  end
end
