defmodule RouteShield.MixProject do
  use Mix.Project

  def project do
    [
      app: :route_shield,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
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
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 0.20 or ~> 1.0"},
      {:ecto_sql, "~> 3.11"},
      {:plug, "~> 1.14"},
      {:jason, "~> 1.4"},
      {:ex_unit_notifier, "~> 1.0", only: :test},
      {:mox, "~> 1.0", only: :test}
    ]
  end
end
