# RabbitMQ adapter for Yggdrasil

[![Build Status](https://travis-ci.org/gmtprime/yggdrasil_rabbitmq.svg?branch=master)](https://travis-ci.org/gmtprime/yggdrasil_rabbitmq) [![Hex pm](http://img.shields.io/hexpm/v/yggdrasil_rabbitmq.svg?style=flat)](https://hex.pm/packages/yggdrasil_rabbitmq) [![hex.pm downloads](https://img.shields.io/hexpm/dt/yggdrasil_rabbitmq.svg?style=flat)](https://hex.pm/packages/yggdrasil_rabbitmq)

This project is a RabbitMQ adapter for `Yggdrasil` pub/sub.

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

## Installation

Using this RabbitMQ adapter with `Yggdrasil` is a matter of adding the
available hex package to your `mix.exs` file e.g:

```elixir
def deps do
  [{:yggdrasil_rabbitmq, "~> 4.0"}]
end
```

## Running the tests

A `docker-compose.yml` file is provided with the project. If  you don't have a
RabbitMQ database, but you do have Docker installed, then just do:

```
$ docker-compose up --build
```

And in another shell run:

```
$ mix deps.get
$ mix test
```

## Relevant projects used

  * [`AMQP`](https://github.com/pma/amqp): AMQP application.
  * [`Connection`](https://github.com/fishcakez/connection): wrapper over
  `GenServer` to handle connections.

## Author

Alexander de Sousa.

## License

`Yggdrasil` is released under the MIT License. See the LICENSE file for further
details.
