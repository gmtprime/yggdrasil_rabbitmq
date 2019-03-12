# Yggdrasil for RabbitMQ

[![Build Status](https://travis-ci.org/gmtprime/yggdrasil_rabbitmq.svg?branch=master)](https://travis-ci.org/gmtprime/yggdrasil_rabbitmq) [![Hex pm](http://img.shields.io/hexpm/v/yggdrasil_rabbitmq.svg?style=flat)](https://hex.pm/packages/yggdrasil_rabbitmq) [![hex.pm downloads](https://img.shields.io/hexpm/dt/yggdrasil_rabbitmq.svg?style=flat)](https://hex.pm/packages/yggdrasil_rabbitmq)

`Yggdrasil` for RabbitMQ is a publisher/subscriber that:

- It's easy to use and configure.
- It's fault tolerant: recovers disconnected subscriptions.
- It has reconnection support: configurable exponential backoff.
- It has OS environment variable configuration support (useful for
[Distillery](https://github.com/bitwalker/distillery) releases)

## Small example

The following example uses RabbitMQ adapter to distribute messages e.g:

Given the following channel:

```elixir
iex> channel = [name: {"amq.topic", "routing.key"}, adapter: :rabbitmq]
```

You can:

* Subscribe to it:

  ```
  iex> Yggdrasil.subscribe(channel)
  iex> flush()
  {:Y_CONNECTED, %Yggdrasil.Channel{(...)}}
  ```

* Publish messages to it:

  ```elixir
  iex(4)> Yggdrasil.publish(channel, "message")
  iex(5)> flush()
  {:Y_EVENT, %Yggdrasil.Channel{(...)}, "message"}
  ```

* Unsubscribe from it:

```elixir
iex(6)> Yggdrasil.unsubscribe(channel)
iex(7)> flush()
{:Y_DISCONNECTED, %Yggdrasil.Channel{(...)}}
```

## RabbitMQ adapter

The RabbitMQ adapter has the following rules:

* The `adapter` name is identified by the atom `:rabbitmq`.
* The channel `name` must be a tuple with the exchange and the routing key.
* The `transformer` must encode to a string. By default, `Yggdrasil`
  provides two transformers: `:default` (default) and `:json`.
* Any `backend` can be used (by default is `:default`).

The following is an example of a valid channel for both publishers and
subscribers:

```elixir
%Yggdrasil.Channel{
  name: {"amq.topic", "my.routing.key"},
  adapter: :rabbitmq,
  transformer: :json
}
```

The previous channel expects to:

- Subscribe to or publish to the exchange `amq.topic` and using the
routing key `my.routing.key`.
- The adapter is `:rabbitmq`, so it will connect to RabbitMQ using the
appropriate adapter.
- The transformer expects valid JSONs when decoding (consuming from a
subscription) and maps or keyword lists when encoding (publishing).

> Note: Though the struct `Yggdrasil.Channel` is used, `Keyword` lists and
> maps are also accepted as channels as long as they contain the required
> keys.

## RabbitMQ configuration

Uses the list of options for `AMQP`, but the more relevant optuons are
shown below:

- `hostname` - RabbitMQ hostname (defaults to `"localhost"`).
- `port` - RabbitMQ port (defaults to `5672`).
- `username` - RabbitMQ username (defaults to `"guest"`).
- `password` - RabbitMQ password (defaults to `"guest"`).
- `virtual_host` - Virtual host (defaults to `"/"`).
- `heartbeat` - Heartbeat of the connections (defaults to `10` seconds).

> For more information about the available options check
> `Yggdrasil.Settings.RabbitMQ`.

The following shows a configuration with and without namespace:

```elixir
# Without namespace
config :yggdrasil,
  rabbitmq: [hostname: "rabbitmq.zero"]

# With namespace
config :yggdrasil, RabbitMQOne,
  rabbitmq: [
    hostname: "rabbitmq.one",
    port: 1234
  ]
```

All the available options are also available as OS environment variables.
It's possible to even separate them by namespace e.g:

Given two namespaces, the default one and `Rabbit.One`, it's possible to
load the `hostname` from the OS environment variables as follows:

- `$YGGDRASIL_RABBITMQ_HOSTNAME` for the default namespace.
- `$RABBIT_ONE_YGGDRASIL_RABBITMQ_HOSTNAME` for `Rabbit.One`.

In general, the namespace will go before the name of the variable.

## Installation

Using this adapter with `Yggdrasil` is a matter of adding the
available hex package to your `mix.exs` file e.g:

```elixir
def deps do
  [{:yggdrasil_rabbitmq, "~> 5.0"}]
end
```

## Running the tests

A `docker-compose.yml` file is provided with the project. If  you don't have a
RabbitMQ server, but you do have Docker installed, then you can run:

```
$ docker-compose up --build
```

And in another shell run:

```
$ mix deps.get
$ mix test
```

## Author

Alexander de Sousa.

## License

`Yggdrasil` is released under the MIT License. See the LICENSE file for further
details.
