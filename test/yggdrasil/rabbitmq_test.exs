defmodule Yggdrasil.RabbitMQTest do
  use ExUnit.Case

  describe "pub/sub" do
    test "API test" do
      channel = [name: {"amq.topic", "full"}, adapter: :rabbitmq]

      assert :ok = Yggdrasil.subscribe(channel)
      assert_receive {:Y_CONNECTED, _}

      assert :ok = Yggdrasil.publish(channel, "message")
      assert_receive {:Y_EVENT, _, "message"}

      assert :ok = Yggdrasil.unsubscribe(channel)
      assert_receive {:Y_DISCONNECTED, _}
    end
  end
end
