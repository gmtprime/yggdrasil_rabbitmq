defmodule YggdrasilRabbitmq.MixProject do
  use Mix.Project

  @version "6.0.0"
  @root "https://github.com/gmtprime/yggdrasil_rabbitmq"

  def project do
    [
      name: "Yggdrasil for RabbitMQ",
      app: :yggdrasil_rabbitmq,
      version: @version,
      elixir: "~> 1.12",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      dialyzer: dialyzer(),
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
      {:yggdrasil, "~> 6.0"},
      {:skogsra, "~> 2.3"},
      {:poolboy, "~> 1.5"},
      {:amqp, "~> 2.0"},
      {:ex_doc, "~> 0.24", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false}
    ]
  end

  def dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/yggdrasil_rabbitmq.plt"}
    ]
  end

  #########
  # Package

  defp package do
    [
      description: "RabbitMQ adapter for Yggdrasil (pub/sub)",
      files: ["lib", "mix.exs", "README.md", "CHANGELOG.md"],
      maintainers: ["Alexander de Sousa"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "#{@root}/blob/master/CHANGELOG.md",
        "Github" => @root
      }
    ]
  end

  ###############
  # Documentation

  defp docs do
    [
      main: "readme",
      source_url: @root,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md"
      ],
      groups_for_modules: groups_for_modules()
    ]
  end

  defp groups_for_modules do
    [
      "RabbitMQ Adapter Settings": [
        Yggdrasil.Settings.RabbitMQ,
        Yggdrasil.Adapter.RabbitMQ
      ],
      "Subscriber adapter": [
        Yggdrasil.Subscriber.Adapter.RabbitMQ
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
