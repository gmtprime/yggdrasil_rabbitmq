defmodule Yggdrasil.Settings.RabbitMQ do
  @moduledoc """
  This module defines the available settings for RabbitMQ in Yggdrasil.
  """
  use Skogsra

  ##########################################################
  # RabbitMQ connection default variables for default domain

  @envdoc """
  RabbitMQ hostname. Defaults to `"localhost"`.
  """
  app_env :yggdrasil_rabbitmq_hostname, :yggdrasil, [:rabbitmq, :hostname],
    default: "localhost"

  @envdoc """
  RabbitMQ port. Defaults to `5672`.
  """
  app_env :yggdrasil_rabbitmq_port, :yggdrasil, [:rabbitmq, :port],
    default: 5672

  @envdoc """
  RabbitMQ username. Defaults to `"guest"`.
  """
  app_env :yggdrasil_rabbitmq_username, :yggdrasil, [:rabbitmq, :username],
    default: "guest"

  @envdoc """
  RabbitMQ password. Defaults to `"guest"`.
  """
  app_env :yggdrasil_rabbitmq_password, :yggdrasil, [:rabbitmq, :password],
    default: "guest"

  @envdoc """
  RabbitMQ virtual host. Defaults to `"/"`.
  """
  app_env :yggdrasil_rabbitmq_virtual_host,
          :yggdrasil,
          [:rabbitmq, :virtual_host],
          default: "/"

  @envdoc """
  RabbitMQ heartbeat. Defaults to `10` seconds.
  """
  app_env :yggdrasil_rabbitmq_heartbeat, :yggdrasil, [:rabbitmq, :heartbeat],
    default: 10

  @envdoc """
  RabbitMQ max retries for the backoff algorithm. Defaults to `12`.

  The backoff algorithm is exponential:
  ```
  backoff_time = pow(2, retries) * random(1, slot) ms
  ```
  when `retries <= MAX_RETRIES` and `slot` is given by the configuration
  variable `#{__MODULE__}.yggdrasil_rabbitmq_slot_size/0` (defaults to `100`
  ms).
  """
  app_env :yggdrasil_rabbitmq_max_retries,
          :yggdrasil,
          [:rabbitmq, :max_retries],
          default: 12

  @envdoc """
  RabbitMQ slot size for the backoff algorithm. Defaults to `100`.
  """
  app_env :yggdrasil_rabbitmq_slot_size, :yggdrasil, [:rabbitmq, :slot_size],
    default: 100

  @envdoc """
  RabbitMQ subscriber options. They are options for `:poolboy`. Defaults to
  `[size: 5, max_overflow: 10].`
  """
  app_env :yggdrasil_rabbitmq_subscriber_options,
          :yggdrasil,
          [:rabbitmq, :subscriber_options],
          default: [size: 5, max_overflow: 10]
end
