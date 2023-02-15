defmodule Papahome.MixProject do
  use Mix.Project

  def project do
    [
      app:             :papahome,
      version:         "0.1.0",
      elixir:          "~> 1.14",
      start_permanent: Mix.env() == :prod,
      elixirc_paths:   elixirc_paths(Mix.env()),
      deps:            deps(),
      aliases:         aliases(),
      escript:         [main_module: Papahome.CLI],
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Papahome.Application, []}
    ]
  end

  # Environment-specific paths
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [
      {:postgrex,          ">= 0.0.0"},
      {:ecto_sql,          "~> 3.6"},
      {:typed_ecto_schema, "~> 0.4.1", runtime: false},
      {:dialyxir,          "~> 1.0",   runtime: false, only: [:dev]},
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop",   "ecto.setup"],
      test:         ["ecto.drop --quiet",
                     "ecto.create --quiet",
                     "ecto.migrate --quiet",
                     "test"
                    ]
    ]
  end
end
