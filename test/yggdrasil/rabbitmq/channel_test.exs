defmodule Yggdrasil.RabbitMQ.ChannelTest do
  use ExUnit.Case

  alias AMQP.Channel, as: RabbitChan
  alias Yggdrasil.RabbitMQ.Channel
  alias Yggdrasil.RabbitMQ.Client

  setup do
    channel =
      spawn(fn ->
        receive do
          _ -> :ok
        end
      end)

    client = %Client{
      pid: self(),
      namespace: __MODULE__,
      tag: :publisher,
      channel: %RabbitChan{pid: channel}
    }

    {:ok, [client: client]}
  end

  describe "start/1" do
    test "inserts the new channel in cache",
         %{client: %Client{channel: channel} = client} do
      assert {:ok, pid} = Channel.start_link(client)
      assert {:ok, ^channel} = Channel.get(pid)
    end
  end
end
