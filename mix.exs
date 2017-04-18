defmodule Kaffeine.Mixfile do
  use Mix.Project

  def project do
    [
      app: :kaffeine,
      build_embedded: Mix.env == :prod,
      deps: deps(),
      description: description(),
      dialyzer: [plt_add_deps: :transitive],
      elixir: "~> 1.4",
      package: package(),
      start_permanent: Mix.env == :prod,
      version: "0.1.0",
    ]
  end

  def application do
    [extra_applications: [:logger],
     mod: {Kaffeine.Application, []}]
  end

  defp deps do
    [
      {:kafka_ex, "~> 0.6"},

      # NON-PRODUCTION DEPS
      {:dialyxir, "~> 0.5", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  def description do
    """
    Framework for consuming Kafka events
    """
  end

  defp package do
    [
      name: :kaffeine,
      maintainers: ["Avvo, Inc", "Donald Plummer"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/avvo/kaffeine"
      }
    ]
  end
end
