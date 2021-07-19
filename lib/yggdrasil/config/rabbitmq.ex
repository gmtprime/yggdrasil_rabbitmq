defmodule Yggdrasil.Config.RabbitMQ do
  @moduledoc """
  This module defines the available config variables for RabbitMQ in Yggdrasil.
  """
  use Skogsra

  ##############################
  # RabbitMQ connection settings

  @envdoc """
  RabbitMQ hostname. Defaults to `"localhost"`.
  """
  app_env :hostname, :yggdrasil, [:rabbitmq, :hostname], default: "localhost"

  @envdoc """
  RabbitMQ port. Defaults to `5672`.
  """
  app_env :port, :yggdrasil, [:rabbitmq, :port], default: 5672

  @envdoc """
  RabbitMQ username. Defaults to `"guest"`.

      iex> Yggdrasil.Config.RabbitMQ.username()
      {:ok, "guest"}
  """
  app_env :username, :yggdrasil, [:rabbitmq, :username], default: "guest"

  @envdoc """
  RabbitMQ password. Defaults to `"guest"`.

      iex> Yggdrasil.Config.RabbitMQ.password()
      {:ok, "guest"}
  """
  app_env :password, :yggdrasil, [:rabbitmq, :password], default: "guest"

  @envdoc """
  RabbitMQ virtual host. Defaults to `"/"`.

      iex> Yggdrasil.Config.RabbitMQ.virtual_host()
      {:ok, "/"}
  """
  app_env :virtual_host, :yggdrasil, [:rabbitmq, :virtual_host], default: "/"

  @envdoc """
  RabbitMQ heartbeat. Defaults to `10` seconds.

      iex> Yggdrasil.Config.RabbitMQ.heartbeat()
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

      iex> Yggdrasil.Config.RabbitMQ.max_retries()
      {:ok, 3}
  """
  app_env :max_retries, :yggdrasil, [:rabbitmq, :max_retries], default: 3

  @envdoc """
  RabbitMQ slot size for the backoff algorithm. Defaults to `10`.

      iex> Yggdrasil.Config.RabbitMQ.slot_size()
      {:ok, 10}
  """
  app_env :slot_size, :yggdrasil, [:rabbitmq, :slot_size], default: 10

  @envdoc """
  RabbitMQ amount of publisher connections.

      iex> Yggdrasil.Config.RabbitMQ.publisher_connections()
      {:ok, 1}
  """
  app_env :publisher_connections,
          :yggdrasil,
          [:rabbitmq, :publisher_connections],
          default: 1

  @envdoc """
  RabbitMQ amount of subscriber connections.

      iex> Yggdrasil.Config.RabbitMQ.subscriber_connections()
      {:ok, 1}
  """
  app_env :subscriber_connections,
          :yggdrasil,
          [:rabbitmq, :subscriber_connections],
          default: 1
end
