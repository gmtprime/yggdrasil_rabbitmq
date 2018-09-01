defmodule YggdrasilRabbitmq.MixProject do
  use Mix.Project

  @version "4.0.0"

  def project do
    [
      app: :yggdrasil_rabbitmq,
      version: @version,
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:lager, :logger],
      mod: {Yggdrasil.RabbitMQ.Application, []}
    ]
  end

  defp deps do
    [
      {:yggdrasil, "~> 4.0"},
      {:poolboy, "~> 1.5"},
      {:amqp, "~> 1.0"},
      {:connection, "~> 1.0"},
      {:uuid, "~> 1.1", only: [:dev, :test]},
      {:ex_doc, "~> 0.18.4", only: :dev},
      {:credo, "~> 0.9", only: :dev}
    ]
  end

  defp docs do
    [source_url: "https://github.com/gmtprime/yggdrasil_rabbitmq",
     source_ref: "v#{@version}",
     main: Yggdrasil.RabbitMQ.Application]
  end

  defp description do
    """
    RabbitMQ adapter for Yggdrasil.
    """
  end

  defp package do
    [maintainers: ["Alexander de Sousa"],
     licenses: ["MIT"],
     links: %{"Github" => "https://github.com/gmtprime/yggdrasil_rabbitmq"}]
  end
end
