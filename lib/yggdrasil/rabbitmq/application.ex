defmodule Yggdrasil.RabbitMQ.Application do
  @moduledoc """
  Module that defines Yggdrasil with RabbitMQ support.

  ![demo](https://raw.githubusercontent.com/gmtprime/yggdrasil_rabbitmq/master/images/demo.gif)

  ## Small example

  The following example uses RabbitMQ adapter to distribute messages:

  ```elixir
  iex(1)> channel = %Yggdrasil.Channel{
  iex(1)>   name: {"amq.topic", "some_channel"},
  iex(1)>   adapter: :rabbitmq
  iex(1)> }
  iex(2)> Yggdrasil.subscribe(channel)
  iex(3)> flush()
  {:Y_CONNECTED, %YggdrasilChannel{(...)}}
  ```

  and to publish a message for the subscribers:

  ```elixir
  iex(4)> Yggdrasil.publish(channel, "message")
  iex(5)> flush()
  {:Y_EVENT, %Yggdrasil.Channel{(...)}, "message"}
  ```

  When the subscriber wants to stop receiving messages, then it can unsubscribe
  from the channel:

  ```elixir
  iex(6)> Yggdrasil.unsubscribe(channel)
  iex(7)> flush()
  {:Y_DISCONNECTED, %Yggdrasil.Channel{(...)}}
  ```

  ## RabbitMQ adapter

  The RabbitMQ adapter has the following rules:
    * The `adapter` name is identified by the atom `:rabbitmq`.
    * The channel `name` must be a tuple with the exchange and the routing key.
    * The `transformer` must encode to a string. From the `transformer`s provided
    it defaults to `:default`, but `:json` can also be used.
    * Any `backend` can be used (by default is `:default`).

  The following is a valid channel for both publishers and subscribers:

  ```elixir
  %Yggdrasil.Channel{
    name: {"amq.topic", "postgres_channel_name"},
    adapter: :rabbitmq,
    transformer: :json
  }
  ```

  It will expect valid JSONs from RabbitMQ and it will write valid JSONs in
  RabbitMQ.

  ## RabbitMQ configuration

  Uses the list of options for `AMQP`, but the more relevant optuons are
  shown below:
    * `hostname` - RabbitMQ hostname (defaults to `"localhost"`).
    * `port` - RabbitMQ port (defaults to `5672`).
    * `username` - RabbitMQ username (defaults to `"guest"`).
    * `password` - RabbitMQ password (defaults to `"guest"`).
    * `virtual_host` - Virtual host (defaults to `"/"`).
    * `subscriber_options` - Controls the amount of connections established with
    RabbitMQ. These are `poolboy` options for RabbitMQ subscriber (defaults to
    `[size: 5, max_overflow: 10]`).

  The following shows a configuration with and without namespace:

  ```elixir
  # Without namespace
  config :yggdrasil,
    rabbitmq: [hostname: "rabbitmq.zero"]

  # With namespace
  config :yggdrasil, RabbitMQOne,
    postgres: [
      hostname: "rabbitmq.one",
      port: 1234
    ]
  ```

  Also the options can be provided as OS environment variables. The available
  variables are:

    * `YGGDRASIL_RABBITMQ_HOSTNAME` or `<NAMESPACE>_YGGDRASIL_RABBITMQ_HOSTNAME`.
    * `YGGDRASIL_RABBITMQ_PORT` or `<NAMESPACE>_YGGDRASIL_RABBITMQ_PORT`.
    * `YGGDRASIL_RABBITMQ_USERNAME` or `<NAMESPACE>_YGGDRASIL_RABBITMQ_USERNAME`.
    * `YGGDRASIL_RABBITMQ_PASSWORD` or `<NAMESPACE>_YGGDRASIL_RABBITMQ_PASSWORD`.
    * `YGGDRASIL_RABBITMQ_VIRTUAL_HOST` or
    `<NAMESPACE>_YGGDRASIL_RABBITMQ_VIRTUAL_HOST`.

  where `<NAMESPACE>` is the snakecase of the namespace chosen e.g. for the
  namespace `RabbitmqTwo`, you would use `RABBITMQ_TWO` as namespace in the OS
  environment variable.
  """
  use Application

  def start(_type, _args) do
    children = [
      Supervisor.child_spec({Yggdrasil.Adapter.RabbitMQ, []}, []),
      Supervisor.child_spec(
        { Yggdrasil.Subscriber.Adapter.RabbitMQ.Generator,
          [name: Yggdrasil.Subscriber.Adapter.RabbitMQ.Generator]
        },
        type: :supervisor
      )
    ]

    opts = [strategy: :one_for_one, name: Yggdrasil.RabbitMQ.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
