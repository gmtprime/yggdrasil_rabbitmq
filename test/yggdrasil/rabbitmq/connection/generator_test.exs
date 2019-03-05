defmodule Yggdrasil.RabbitMQ.Connection.GeneratorTest do
  use ExUnit.Case

  alias AMQP.Channel
  alias Yggdrasil.RabbitMQ.Connection.Generator

  describe "open_channel/1" do
    test "returns a new channel" do
      assert {:ok, %Channel{pid: pid}} = Generator.open_channel(:subscriber, nil)
      assert is_pid(pid) and Process.alive?(pid)
    end

    test "returns the same channel for the same process" do
      assert {:ok, %Channel{pid: pid}} = Generator.open_channel(:subscriber, nil)
      assert {:ok, %Channel{pid: ^pid}} = Generator.open_channel(:subscriber, nil)
    end

    test "returns an error when no connection is available" do
      namespace = Disconnected
      config = [rabbitmq: [hostname: "disconnected"]]
      Application.put_env(:yggdrasil, namespace, config)

      assert {:error, _} = Generator.open_channel(:subscriber, namespace)
    end
  end
end
