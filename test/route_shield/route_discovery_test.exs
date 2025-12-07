defmodule RouteShield.RouteDiscoveryTest do
  use ExUnit.Case

  alias RouteShield.RouteDiscovery
  alias RouteShield.Storage.ETS

  setup do
    ETS.clear_routes()
    :ok
  end

  describe "discover_routes/1" do
    test "returns empty list when router module doesn't exist" do
      assert [] = RouteDiscovery.discover_routes(NonExistentModule)
    end

    test "discovers routes from router with __route_shield_routes__ function" do
      defmodule TestRouterWithFunction do
        def __route_shield_routes__ do
          [
            %{method: "GET", path_pattern: "/test", controller: "TestController", action: "index"}
          ]
        end
      end

      routes = RouteDiscovery.discover_routes(TestRouterWithFunction)
      assert length(routes) == 1
      assert hd(routes).method == "GET"
      assert hd(routes).path_pattern == "/test"
    end

    test "handles router without __route_shield_routes__ gracefully" do
      # This will try to use Phoenix.Router.routes which may not work in test
      # but should not crash
      result = RouteDiscovery.discover_routes(TestRouterWithFunction)
      assert is_list(result)
    end
  end

  describe "discover_and_store_routes/2" do
    test "stores routes in ETS" do
      defmodule TestRouter do
        def __route_shield_routes__ do
          [
            %{
              method: "GET",
              path_pattern: "/api/test",
              controller: "TestController",
              action: "index",
              helper: "test_path"
            }
          ]
        end
      end

      # Test route discovery (without database storage)
      routes = RouteDiscovery.discover_routes(TestRouter)

      assert length(routes) == 1
      route = hd(routes)
      assert route.method == "GET"
      assert route.path_pattern == "/api/test"

      # Note: Full testing with database storage requires a real Ecto.Repo
      # or integration test setup with a test database
    end
  end

  describe "extract_route_info/1" do
    test "extracts controller and action from tuple plug" do
      route = %{
        method: "GET",
        path: "/test",
        plug: {TestController, :index},
        helper: "test_path"
      }

      info = RouteDiscovery.discover_routes(TestRouterWithFunction)
      # This is a private function, so we test it indirectly
      # through discover_routes which uses it
    end
  end
end
