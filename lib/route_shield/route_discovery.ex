 defmodule RouteShield.RouteDiscovery do
  @moduledoc """
  Handles route discovery and storage in ETS and database.
  """

  alias RouteShield.Storage.ETS
  alias RouteShield.Schema.Route

  def discover_and_store_routes(router_module, repo) do
    routes = discover_routes(router_module)
    db_routes = store_routes_in_db(routes, repo)
    store_routes_in_ets(db_routes)
    db_routes
  end

  def discover_routes(router_module) do
    routes =
      if function_exported?(router_module, :__route_shield_routes__, 0) do
        router_module.__route_shield_routes__()
      else
        try do
          router_module
          |> Phoenix.Router.routes()
          |> Enum.map(&extract_route_info/1)
        rescue
          _ -> []
        end
      end

    # Filter out static assets and internal routes
    routes
    |> Enum.filter(&should_include_route?/1)
  end

  defp should_include_route?(route) do
    path = route.path_pattern || ""

    # Exclude static asset routes
    excluded_paths = [
      "/assets",
      "/css",
      "/js",
      "/images",
      "/fonts",
      "/favicon.ico",
      "/robots.txt"
    ]

    # Exclude Phoenix internal routes
    excluded_prefixes = [
      "/phoenix",
      "/live",
      "/dev"
    ]

    # Check if path starts with any excluded prefix
    excluded_by_prefix? =
      Enum.any?(excluded_prefixes, fn prefix ->
        String.starts_with?(path, prefix)
      end)

    # Check if path matches any excluded path
    excluded_by_path? = path in excluded_paths

    # Only include routes that:
    # 1. Don't match excluded paths/prefixes
    # 2. Have a controller (actual API/controller routes, not static files)
    not excluded_by_prefix? and
      not excluded_by_path? and
      not is_nil(route.controller)
  end

  defp extract_route_info(route) do
    %{
      method: String.upcase(to_string(route.verb)),
      path_pattern: route.path,
      controller: extract_controller(route),
      action: extract_action(route),
      helper: route.helper
    }
  end

  defp extract_controller(route) do
    case route.plug do
      {controller, _action} -> inspect(controller)
      controller when is_atom(controller) -> inspect(controller)
      _ -> nil
    end
  end

  defp extract_action(route) do
    case route.plug do
      {_controller, action} -> to_string(action)
      _ -> nil
    end
  end

  defp store_routes_in_ets(routes) do
    routes
    |> Enum.each(fn route ->
      # Routes are already Route structs from the database
      ETS.store_route(route)
    end)
  end

  defp store_routes_in_db(routes, repo) do
    now = DateTime.utc_now()

    routes
    |> Enum.map(fn route ->
      attrs = Map.put(route, :discovered_at, now)

      case repo.get_by(Route, method: route.method, path_pattern: route.path_pattern) do
        nil ->
          case Route.changeset(%Route{}, attrs) |> repo.insert() do
            {:ok, db_route} -> db_route
            {:error, _} -> nil
          end

        existing_route ->
          case Route.changeset(existing_route, attrs) |> repo.update() do
            {:ok, db_route} -> db_route
            {:error, _} -> existing_route
          end
      end
    end)
    |> Enum.filter(& &1)
  end
end
