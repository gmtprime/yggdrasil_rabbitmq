defmodule Yggdrasil.Settings.RabbitMQ do
  @moduledoc """
  This module defines the available settings for RabbitMQ in Yggdrasil.
  """
  use Skogsra

  ##############################
  # RabbitMQ connection settings

  @envdoc """
  RabbitMQ hostname. Defaults to `"localhost"`.

      iex> Yggdrasil.Settings.RabbitMQ.localhost()
      {:ok, "localhost"}
  """
  app_env :hostname, :yggdrasil, [:rabbitmq, :hostname], default: "localhost"

  @envdoc """
  RabbitMQ port. Defaults to `5672`.

      iex> Yggdrasil.Settings.RabbitMQ.port()
      {:ok, 5672}
  """
  app_env :port, :yggdrasil, [:rabbitmq, :port], default: 5672

  @envdoc """
  RabbitMQ username. Defaults to `"guest"`.

      iex> Yggdrasil.Settings.RabbitMQ.username()
      {:ok, "guest"}
  """
  app_env :username, :yggdrasil, [:rabbitmq, :username], default: "guest"

  @envdoc """
  RabbitMQ password. Defaults to `"guest"`.

      iex> Yggdrasil.Settings.RabbitMQ.password()
      {:ok, "guest"}
  """
  app_env :password, :yggdrasil, [:rabbitmq, :password], default: "guest"

  @envdoc """
  RabbitMQ virtual host. Defaults to `"/"`.

      iex> Yggdrasil.Settings.RabbitMQ.virtual_host()
      {:ok, "/"}
  """
  app_env :virtual_host, :yggdrasil, [:rabbitmq, :virtual_host], default: "/"

  @envdoc """
  RabbitMQ heartbeat. Defaults to `10` seconds.

      iex> Yggdrasil.Settings.RabbitMQ.heartbeat()
      {:ok, 10}
  """
  app_env :heartbeat, :yggdrasil, [:rabbitmq, :heartbeat], default: 10

  @envdoc """
  RabbitMQ max retries for the backoff algorithm. Defaults to `3`.

  The backoff algorithm is exponential:
  ```
  backoff_time = pow(2, retries) * random(1, slot) * 1_000 ms
  ```
  when `retries <= MAX_RETRIES` and `slot` is given by the configuration
  variable `#{__MODULE__}.slot_size/0` (defaults to `10` secs).

      iex> Yggdrasil.Settings.RabbitMQ.max_retries()
      {:ok, 3}
  """
  app_env :max_retries, :yggdrasil, [:rabbitmq, :max_retries], default: 3

  @envdoc """
  RabbitMQ slot size for the backoff algorithm. Defaults to `10`.

      iex> Yggdrasil.Settings.RabbitMQ.slot_size()
      {:ok, 10}
  """
  app_env :slot_size, :yggdrasil, [:rabbitmq, :slot_size], default: 10

  @envdoc """
  RabbitMQ amount of publisher connections.

      iex> Yggdrasil.Settings.RabbitMQ.publisher_connections()
      {:ok, 1}
  """
  app_env :publisher_connections,
          :yggdrasil,
          [:rabbitmq, :publisher_connections],
          default: 1

  @envdoc """
  RabbitMQ amount of subscriber connections.

      iex> Yggdrasil.Settings.RabbitMQ.subscriber_connections()
      {:ok, 1}
  """
  app_env :subscriber_connections,
          :yggdrasil,
          [:rabbitmq, :subscriber_connections],
          default: 1

  @envdoc """
  RabbitMQ subscriber options. They are options for `:poolboy`. Defaults to
  `[size: 5, max_overflow: 10].`

      iex> Yggdrasil.Settings.RabbitMQ.yggdrasil_rabbitmq_subscribe_options()
      {:ok, [size: 5, max_overflow: 10]}
  """
  app_env :subscriber_options,
          :yggdrasil,
          [:rabbitmq, :subscriber_options],
          default: [size: 5, max_overflow: 10]
end
