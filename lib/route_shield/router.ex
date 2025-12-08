defmodule RouteShield.Router do
  @moduledoc """
  Compile-time route discovery using @before_compile hook.
  This module introspects the Phoenix router to extract all routes.
  """

  defmacro __using__(_opts) do
    quote do
      @before_compile RouteShield.Router
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __route_shield_routes__ do
        __MODULE__
        |> Phoenix.Router.routes()
        |> Enum.filter(&should_include_raw_route?/1)
        |> Enum.map(&extract_route_info/1)
      end

      defp should_include_raw_route?(route) do
        # route is a Phoenix.Router route struct with :path field
        path = route.path || ""

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

        # Check if route has a controller (actual API/controller routes)
        has_controller? =
          case route.plug do
            {_controller, _action} -> true
            controller when is_atom(controller) -> true
            _ -> false
          end

        # Only include routes that:
        # 1. Don't match excluded paths/prefixes
        # 2. Have a controller (actual API/controller routes, not static files)
        not excluded_by_prefix? and
          not excluded_by_path? and
          has_controller?
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
    end
  end
end
