defmodule YggdrasilRabbitmq.MixProject do
  use Mix.Project

  @version "5.0.0"
  @root "https://github.com/gmtprime/yggdrasil_rabbitmq"

  def project do
    [
      app: :yggdrasil_rabbitmq,
      version: @version,
      elixir: "~> 1.8",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      docs: docs()
    ]
  end

  #############
  # Application

  def application do
    [
      extra_applications: [:lager, :logger],
      mod: {Yggdrasil.RabbitMQ.Application, []}
    ]
  end

  defp deps do
    [
      {:yggdrasil, "~> 4.1"},
      {:poolboy, "~> 1.5"},
      {:amqp, "~> 1.1"},
      {:uuid, "~> 1.1", only: [:dev, :test]},
      {:ex_doc, "~> 0.19", only: :dev},
      {:credo, "~> 1.0", only: :dev}
    ]
  end

  #########
  # Package

  defp package do
    [
      description: "RabbitMQ adapter for Yggdrasil (pub/sub)",
      files: ["lib", "mix.exs", "README.md"],
      maintainers: ["Alexander de Sousa"],
      licenses: ["MIT"],
      links: %{
        "Github" => @root
      }
    ]
  end

  ###############
  # Documentation

  defp docs do
    [
      source_url: @root,
      source_ref: "v#{@version}",
      main: "readme",
      formatters: ["html"],
      groups_for_modules: groups_for_modules(),
      extras: ["README.md"]
    ]
  end

  defp groups_for_modules do
    [
      "RabbitMQ Adapter Settings": [
        Yggdrasil.Settings.RabbitMQ,
        Yggdrasil.Adapter.RabbitMQ
      ],
      "Subscriber adapter": [
        Yggdrasil.Subscriber.Adapter.RabbitMQ,
      ],
      "Publisher adapter": [
        Yggdrasil.Publisher.Adapter.RabbitMQ
      ],
      "RabbitMQ Connection Handling": [
        Yggdrasil.RabbitMQ.Connection,
        Yggdrasil.RabbitMQ.Connection.Pool,
        Yggdrasil.RabbitMQ.Connection.Generator
      ],
      "RabbitMQ Channel Handling": [
        Yggdrasil.RabbitMQ.Client,
        Yggdrasil.RabbitMQ.Channel,
        Yggdrasil.RabbitMQ.Channel.Generator
      ]
    ]
  end
end
