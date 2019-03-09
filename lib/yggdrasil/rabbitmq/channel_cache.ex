defmodule Yggdrasil.RabbitMQ.ChannelCache do
  @moduledoc """
  This module defines a channel cache.
  """
  alias AMQP.Channel, as: RabbitChan
  alias Yggdrasil.RabbitMQ.Client

  @doc """
  Creates a new channel cache.
  """
  @spec new() :: :ets.tab()
  def new do
    options = [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ]

    :ets.new(__MODULE__, options)
  end

  @doc """
  Looks up a channel given a `client` struct.
  """
  @spec lookup(Client.t()) :: {:ok, RabbitChan.t()} | {:error, term()}
  def lookup(client)

  def lookup(%Client{} = client) do
    lookup(__MODULE__, client)
  end

  @doc false
  @spec lookup(:ets.tab(), Client.t()) ::
          {:ok, RabbitChan.t()} | {:error, term()}
  def lookup(cache, client)

  def lookup(cache, %Client{} = client) do
    key = Client.get_key(client)

    with [{^key, %RabbitChan{} = channel} | _] <- :ets.lookup(cache, key),
         true <- Process.alive?(channel.pid) do
      {:ok, channel}
    else
      _ ->
        {:error, "Channel not found"}
    end
  end

  @doc """
  Inserts a new channel for a `client`.
  """
  @spec insert(Client.t()) :: :ok
  def insert(client)

  def insert(%Client{} = client) do
    insert(__MODULE__, client)
  end

  @doc false
  @spec insert(:ets.tab(), Client.t()) :: :ok
  def insert(cache, %Client{channel: %RabbitChan{} = channel} = client) do
    key = Client.get_key(client)

    with [] <- :ets.lookup(cache, key) do
      :ets.insert(cache, {key, channel})
    end

    :ok
  end

  @doc """
  Deletes a `client` channel from the cache.
  """
  @spec delete(Client.t()) :: :ok
  def delete(client)

  def delete(%Client{} = client) do
    delete(__MODULE__, client)
  end

  @doc false
  @spec delete(:ets.tab(), Client.t()) :: :ok
  def delete(cache, %Client{} = client) do
    key = Client.get_key(client)
    :ets.delete(cache, key)
    :ok
  end
end
