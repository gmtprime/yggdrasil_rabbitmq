defmodule Yggdrasil.RabbitMQ.Connection.GeneratorTest do
  use ExUnit.Case

  alias AMQP.Channel
  alias Yggdrasil.RabbitMQ.Client
  alias Yggdrasil.RabbitMQ.Connection.Generator

  setup do
    client = %Client{pid: self(), tag: :publisher, namespace: __MODULE__}
    {:ok, [client: client]}
  end

  describe "with_channel/2" do
    test "returns a new channel", %{client: client} do
      assert {:ok, %Channel{pid: pid}} = Generator.with_channel(client)
      assert is_pid(pid) and Process.alive?(pid)
    end

    test "returns the same channel for the same process", %{client: client} do
      assert {:ok, channel} = Generator.with_channel(client)
      assert {:ok, ^channel} = Generator.with_channel(client)
    end

    test "returns an error when no connection is available",
           %{client: client} do
      namespace = __MODULE__.Disconnected
      config = [rabbitmq: [hostname: "disconnected"]]
      Application.put_env(:yggdrasil, namespace, config)

      client = %Client{client | namespace: namespace}

      assert {:error, _} = Generator.with_channel(client)
    end
  end

  describe "with_channel/3" do
    test "returns a custom callback", %{client: client} do
      callback = fn _channel -> :ok end

      assert :ok = Generator.with_channel(client, callback)
    end
  end
end
