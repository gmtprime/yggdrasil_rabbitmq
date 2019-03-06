defmodule Yggdrasil.RabbitMQ.Connection.GeneratorTest do
  use ExUnit.Case

  alias AMQP.Channel
  alias Yggdrasil.RabbitMQ.Connection.Generator

  describe "with_channel/2" do
    test "returns a new channel" do
      tag = :publisher

      assert {:ok, %Channel{pid: pid}} = Generator.with_channel(tag, nil)
      assert is_pid(pid) and Process.alive?(pid)
    end

    test "returns the same channel for the same process" do
      tag = :publisher

      assert {:ok, %Channel{pid: pid}} = Generator.with_channel(tag, nil)
      assert {:ok, %Channel{pid: ^pid}} = Generator.with_channel(tag, nil)
    end

    test "returns an error when no connection is available" do
      tag = :publisher
      namespace = Disconnected
      config = [rabbitmq: [hostname: "disconnected"]]
      Application.put_env(:yggdrasil, namespace, config)

      assert {:error, _} = Generator.with_channel(tag, namespace)
    end
  end

  describe "with_channel/3" do
    test "returns a custom callback" do
      tag = :publisher
      callback = fn _channel -> :ok end

      assert :ok = Generator.with_channel(tag, nil, callback)
    end
  end
end
