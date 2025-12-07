defmodule RouteShield.MixProject do
  use Mix.Project

  def project do
    [
      app: :route_shield,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {RouteShield.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.7.0"},
      {:phoenix_live_view, "~> 0.20.0"},
      {:ecto_sql, "~> 3.11"},
      {:plug, "~> 1.14"},
      {:jason, "~> 1.4"}
    ]
  end
end
