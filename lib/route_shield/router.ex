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
        |> Enum.map(&extract_route_info/1)
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
    end
  end
end
