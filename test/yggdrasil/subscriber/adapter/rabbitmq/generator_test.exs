defmodule Yggdrasil.Subscriber.Adapter.RabbitMQ.GeneratorTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Subscriber.Adapter.RabbitMQ.Generator

  test "connect and open_channel" do
    assert {:ok, pid} = Generator.start_link()
    assert {:ok, _} = Generator.connect(pid, GeneratorNamespace0)
    assert {:ok, chan} = Generator.open_channel(GeneratorNamespace0)
    assert Process.alive?(chan.conn.pid)
    assert Process.alive?(chan.pid)
    assert :ok = Generator.stop(pid)
  end

  test "close_channel" do
    assert {:ok, pid} = Generator.start_link()
    assert {:ok, _} = Generator.connect(pid, GeneratorNamespace1)
    assert {:ok, chan} = Generator.open_channel(GeneratorNamespace1)
    ref = Process.monitor(chan.pid)
    assert :ok = Generator.close_channel(chan)
    assert Process.alive?(chan.conn.pid)
    assert_receive {:DOWN, ^ref, :process, _, :normal}
    assert :ok = Generator.stop(pid)
  end
end
