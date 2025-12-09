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
        # Try to load rules, but handle case where repo isn't started yet
        try do
          # Check if repo process is running
          if repo_available?(repo) do
            # Load all rules, rate limits, and IP filters from database into ETS
            RouteShield.Storage.Cache.refresh_all(repo)

            # Load routes from database into ETS
            load_routes_on_startup(repo)

            # Optionally auto-discover routes on startup if configured
            auto_discover_routes(repo)
          else
            # Repo not started yet, will be loaded when dashboard is accessed
            require Logger
            Logger.info("RouteShield: Repo not available yet, rules will be loaded on first dashboard access")
          end
        rescue
          error ->
            # Repo not available or other error, will be loaded later
            require Logger
            Logger.warning("RouteShield: Could not load rules on startup: #{inspect(error)}. Rules will be loaded on first dashboard access.")
        end
    end
  end

  defp repo_available?(repo) do
    # Check if the repo process is running
    case Process.whereis(repo) do
      nil -> false
      _pid -> true
    end
  rescue
    _ -> false
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
