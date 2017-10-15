defmodule Kaffeine.Mixfile do
  use Mix.Project

  def project do
    [
      app: :kaffeine,
      build_embedded: Mix.env == :prod,
      deps: deps(),
      description: description(),
      dialyzer: [plt_add_deps: :transitive],
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env),
      package: package(),
      start_permanent: Mix.env == :prod,
      version: "0.1.1",
    ]
  end

  def application do
    [extra_applications: [:logger],
     mod: {Kaffeine.Application, []}]
  end

  defp deps do
    [
      {:kafka_ex, "~> 0.6"},
      #{:kafka_impl, "~> 0.4"},
      {:kafka_impl, github: "avvo/kafka_impl", branch: "process-tree"},
      {:env_config, "~> 0.1"},

      # NON-PRODUCTION DEPS
      {:dialyxir, "~> 0.5", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:mix_test_watch, "~> 0.3", only: :dev, runtime: false},
      {:junit_formatter, github: "victorolinasc/junit-formatter", only: [:test]},
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

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]
end
