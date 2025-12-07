defmodule Mix.Tasks.RouteShield.Discover do
  @moduledoc """
  Discovers routes from your Phoenix router and stores them in the database.

  Usage:
      mix route_shield.discover MyApp.Router
  """
  use Mix.Task

  @shortdoc "Discovers routes from Phoenix router"

  def run([router_module_string]) do
    Mix.Task.run("app.start")

    router_module = Module.concat([router_module_string])
    repo = get_repo()

    Mix.shell().info("Discovering routes from #{inspect(router_module)}...")

    routes = RouteShield.discover_routes(router_module, repo)

    Mix.shell().info("Discovered #{length(routes)} routes")
    Mix.shell().info("Routes stored in database and ETS cache")
  end

  def run(_) do
    Mix.shell().error("Usage: mix route_shield.discover YourApp.Router")
  end

  defp get_repo do
    Application.get_env(:route_shield, :repo) ||
      raise "RouteShield repo not configured. Set config :route_shield, repo: YourApp.Repo"
  end
end
