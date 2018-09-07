defmodule Yggdrasil.Subscriber.Adapter.RabbitMQTest do
  use ExUnit.Case, async: true


  alias Yggdrasil.Channel
  alias Yggdrasil.Registry
  alias Yggdrasil.Backend
  alias Yggdrasil.Subscriber.Publisher
  alias Yggdrasil.Subscriber.Manager
  alias Yggdrasil.Subscriber.Adapter
  alias Yggdrasil.Subscriber.Adapter.RabbitMQ
  alias Yggdrasil.Settings

  @registry Settings.yggdrasil_process_registry()

  test "distribute message" do
    routing = "t#{UUID.uuid4() |> :erlang.phash2() |> to_string()}"
    name = {"amq.topic", routing}
    channel = %Channel{name: name, adapter: :rabbitmq, namespace: RabbitMQTest}
    {:ok, channel} = Registry.get_full_channel(channel)
    Backend.subscribe(channel)
    publisher = {:via, @registry, {Publisher, channel}}
    manager = {:via, @registry, {Manager, channel}}
    assert {:ok, _} = Publisher.start_link(channel, name: publisher)
    assert {:ok, _} = Manager.start_link(channel, name: manager)
    :ok = Manager.add(channel, self())

    assert {:ok, adapter} = Adapter.start_link(channel)
    assert_receive {:Y_CONNECTED, ^channel}, 500

    options = RabbitMQ.rabbitmq_options(channel)
    {:ok, conn} = AMQP.Connection.open(options)
    {:ok, chan} = AMQP.Channel.open(conn)
    :ok = AMQP.Basic.publish(chan, "amq.topic", routing, "message")
    :ok = AMQP.Connection.close(conn)

    assert_receive {:Y_EVENT, ^channel, "message"}, 500

    assert :ok = Adapter.stop(adapter)
    assert_receive {:Y_DISCONNECTED, ^channel}, 500
  end
end
