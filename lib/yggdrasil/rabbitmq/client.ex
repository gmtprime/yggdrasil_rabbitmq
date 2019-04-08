defmodule Yggdrasil.RabbitMQ.Client do
  @moduledoc """
  This module defines a RabbitMQ client.
  """
  alias AMQP.Channel, as: RabbitChan
  alias Yggdrasil.RabbitMQ.Connection

  @doc """
  RabbitMQ client connection.
  """
  defstruct [:namespace, :tag, :pid, :channel]
  alias __MODULE__

  @typedoc """
  Tag for client connection.
  """
  @type tag :: :subscriber | :publisher

  @typedoc """
  RabbitMQ client connection.
  """
  @type t :: %Client{
          namespace: namespace :: Connection.namespace(),
          tag: tag :: tag(),
          pid: pid :: pid(),
          channel: channel :: RabbitChan.t()
        }

  @doc """
  Gets a new client with `pid`, `tag` and `namespace`
  """
  def new(pid, tag, namespace) do
    %Client{
      pid: pid,
      tag: tag,
      namespace: namespace
    }
  end

  @doc """
  Gets client key.
  """
  def get_key(%Client{namespace: namespace, tag: tag, pid: client}) do
    {:client, client, tag, namespace}
  end
end
