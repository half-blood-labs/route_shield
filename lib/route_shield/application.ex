defmodule RouteShield.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    RouteShield.Storage.ETS.start_link()
    RouteShield.Rules.RateLimit.init()
    RouteShield.Rules.ConcurrentLimit.init()

    # Load rules from database into ETS on startup
    load_rules_on_startup()

    children = []

    opts = [strategy: :one_for_one, name: RouteShield.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp load_rules_on_startup do
    case Application.get_env(:route_shield, :repo) do
      nil ->
        # Repo not configured yet, skip loading
        :ok

      repo ->
        # Load all rules, rate limits, and IP filters from database into ETS
        RouteShield.Storage.Cache.refresh_all(repo)

        # Load routes from database into ETS
        load_routes_on_startup(repo)

        # Optionally auto-discover routes on startup if configured
        auto_discover_routes(repo)
    end
  end

  defp load_routes_on_startup(repo) do
    alias RouteShield.Schema.Route
    alias RouteShield.Storage.ETS

    routes = repo.all(Route)
    Enum.each(routes, &ETS.store_route/1)
  end

  defp auto_discover_routes(repo) do
    case Application.get_env(:route_shield, :auto_discover_routes) do
      {router_module, true} ->
        # Auto-discover routes on startup
        RouteShield.discover_routes(router_module, repo)

      _ ->
        # Auto-discovery disabled or not configured
        :ok
    end
  end
end
