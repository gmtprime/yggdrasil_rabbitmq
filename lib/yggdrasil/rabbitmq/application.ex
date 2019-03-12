defmodule Yggdrasil.RabbitMQ.Application do
  @moduledoc false
  use Application

  alias Yggdrasil.Adapter.RabbitMQ
  alias Yggdrasil.RabbitMQ.Channel.Generator, as: ChannelGen
  alias Yggdrasil.RabbitMQ.Connection.Generator, as: ConnectionGen

  def start(_type, _args) do

    children = [
      Supervisor.child_spec({ConnectionGen, [name: ConnectionGen]}, type: :supervisor),
      Supervisor.child_spec({ChannelGen, [name: ChannelGen]}, type: :supervisor),
      Supervisor.child_spec({RabbitMQ, []}, [])
    ]

    opts = [strategy: :rest_for_one, name: Yggdrasil.RabbitMQ.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
