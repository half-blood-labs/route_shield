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
  end

  defp extract_route_info(route) do
    %{
      method: route.method,
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
      route_struct = struct(Route, Map.put(route, :discovered_at, DateTime.utc_now()))
      ETS.store_route(route_struct)
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
