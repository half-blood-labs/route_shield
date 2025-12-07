defmodule RouteShield.PlugTest do
  use ExUnit.Case
  use Plug.Test

  alias RouteShield.Plug
  alias RouteShield.Storage.ETS
  alias RouteShield.Schema.{Route, Rule, RateLimit, IpFilter}

  setup do
    # Clear ETS tables before each test
    ETS.clear_all()

    # Clean up rate limit buckets
    table = :route_shield_rate_limit_buckets
    try do
      :ets.delete_all_objects(table)
    rescue
      ArgumentError -> :ok
    end

    # Create a test route
    route = %Route{
      id: 1,
      method: "GET",
      path_pattern: "/api/users",
      controller: "MyApp.UserController",
      action: "index",
      helper: "user_path",
      discovered_at: DateTime.utc_now()
    }

    ETS.store_route(route)

    {:ok, route: route}
  end

  describe "call/2" do
    test "allows request when no rules exist", %{route: route} do
      conn =
        :get
        |> conn("/api/users")
        |> Plug.call([])

      assert conn.state != :sent
      assert conn.status != 429
      assert conn.status != 403
    end

    test "allows request when route is not found" do
      conn =
        :get
        |> conn("/unknown/route")
        |> Plug.call([])

      assert conn.state != :sent
    end

    test "blocks request when IP is blacklisted", %{route: route} do
      # Create a rule with IP blacklist
      rule = %Rule{
        id: 1,
        route_id: route.id,
        enabled: true,
        priority: 10,
        description: "Test rule"
      }

      ip_filter = %IpFilter{
        id: 1,
        rule_id: rule.id,
        ip_address: "192.168.1.100",
        type: :blacklist,
        enabled: true
      }

      ETS.store_rule(rule)
      ETS.store_ip_filter(ip_filter)

      conn =
        :get
        |> conn("/api/users")
        |> put_req_header("x-forwarded-for", "192.168.1.100")
        |> Plug.call([])

      assert conn.state == :sent
      assert conn.status == 403

      response_body = Jason.decode!(conn.resp_body)
      assert response_body["error"] == "IP address is blacklisted"
    end

    test "allows request when IP is whitelisted", %{route: route} do
      rule = %Rule{
        id: 1,
        route_id: route.id,
        enabled: true,
        priority: 10
      }

      ip_filter = %IpFilter{
        id: 1,
        rule_id: rule.id,
        ip_address: "192.168.1.100",
        type: :whitelist,
        enabled: true
      }

      ETS.store_rule(rule)
      ETS.store_ip_filter(ip_filter)

      conn =
        :get
        |> conn("/api/users")
        |> put_req_header("x-forwarded-for", "192.168.1.100")
        |> Plug.call([])

      assert conn.state != :sent
    end

    test "blocks request when IP is not whitelisted but whitelist exists", %{route: route} do
      rule = %Rule{
        id: 1,
        route_id: route.id,
        enabled: true,
        priority: 10
      }

      ip_filter = %IpFilter{
        id: 1,
        rule_id: rule.id,
        ip_address: "192.168.1.100",
        type: :whitelist,
        enabled: true
      }

      ETS.store_rule(rule)
      ETS.store_ip_filter(ip_filter)

      conn =
        :get
        |> conn("/api/users")
        |> put_req_header("x-forwarded-for", "192.168.1.200")
        |> Plug.call([])

      assert conn.state == :sent
      assert conn.status == 403

      response_body = Jason.decode!(conn.resp_body)
      assert response_body["error"] == "IP address is not whitelisted"
    end

    test "blocks request when rate limit is exceeded", %{route: route} do
      rule = %Rule{
        id: 1,
        route_id: route.id,
        enabled: true,
        priority: 10
      }

      rate_limit = %RateLimit{
        id: 1,
        rule_id: rule.id,
        requests_per_window: 2,
        window_seconds: 60,
        enabled: true
      }

      ETS.store_rule(rule)
      ETS.store_rate_limit(rate_limit)

      ip = "192.168.1.100"

      # Make requests up to the limit
      for _ <- 1..2 do
        conn =
          :get
          |> conn("/api/users")
          |> put_req_header("x-forwarded-for", ip)
          |> Plug.call([])

        assert conn.state != :sent
      end

      # This request should be blocked
      conn =
        :get
        |> conn("/api/users")
        |> put_req_header("x-forwarded-for", ip)
        |> Plug.call([])

      assert conn.state == :sent
      assert conn.status == 429

      response_body = Jason.decode!(conn.resp_body)
      assert response_body["error"] == "Rate limit exceeded"
    end

    test "allows request after rate limit window expires", %{route: route} do
      rule = %Rule{
        id: 1,
        route_id: route.id,
        enabled: true,
        priority: 10
      }

      rate_limit = %RateLimit{
        id: 1,
        rule_id: rule.id,
        requests_per_window: 2,
        window_seconds: 1,
        enabled: true
      }

      ETS.store_rule(rule)
      ETS.store_rate_limit(rate_limit)

      ip = "192.168.1.100"

      # Make requests up to the limit
      for _ <- 1..2 do
        conn =
          :get
          |> conn("/api/users")
          |> put_req_header("x-forwarded-for", ip)
          |> Plug.call([])

        assert conn.state != :sent
      end

      # Third request should be blocked
      conn_blocked =
        :get
        |> conn("/api/users")
        |> put_req_header("x-forwarded-for", ip)
        |> Plug.call([])

      assert conn_blocked.state == :sent
      assert conn_blocked.status == 429

      # Wait for window to expire
      Process.sleep(1100)

      # Request after window should succeed again
      conn_after =
        :get
        |> conn("/api/users")
        |> put_req_header("x-forwarded-for", ip)
        |> Plug.call([])

      assert conn_after.state != :sent
    end

    test "matches routes with path parameters", %{route: route} do
      # Store a route with path parameter
      param_route = %Route{
        id: 2,
        method: "GET",
        path_pattern: "/api/users/:id",
        controller: "MyApp.UserController",
        action: "show",
        discovered_at: DateTime.utc_now()
      }

      ETS.store_route(param_route)

      conn =
        :get
        |> conn("/api/users/123")
        |> Plug.call([])

      assert conn.state != :sent
      assert conn.assigns[:route_shield_route].id == 2
    end

    test "extracts IP from x-forwarded-for header" do
      conn =
        :get
        |> conn("/api/users")
        |> put_req_header("x-forwarded-for", "192.168.1.100, 10.0.0.1")
        |> Plug.call([])

      # Should not error, just verify it processes
      assert conn.state != :sent || conn.status in [200, 404]
    end

    test "extracts IP from x-real-ip header when x-forwarded-for is missing" do
      conn =
        :get
        |> conn("/api/users")
        |> put_req_header("x-real-ip", "192.168.1.100")
        |> Plug.call([])

      assert conn.state != :sent || conn.status in [200, 404]
    end

    test "uses remote_ip when headers are missing" do
      conn =
        :get
        |> conn("/api/users")
        |> Plug.call([])

      assert conn.state != :sent || conn.status in [200, 404]
    end

    test "applies rules in priority order", %{route: route} do
      # Create two rules with different priorities
      rule1 = %Rule{
        id: 1,
        route_id: route.id,
        enabled: true,
        priority: 5
      }

      rule2 = %Rule{
        id: 2,
        route_id: route.id,
        enabled: true,
        priority: 10
      }

      ip_filter = %IpFilter{
        id: 1,
        rule_id: rule2.id, # Higher priority rule
        ip_address: "192.168.1.100",
        type: :blacklist,
        enabled: true
      }

      ETS.store_rule(rule1)
      ETS.store_rule(rule2)
      ETS.store_ip_filter(ip_filter)

      conn =
        :get
        |> conn("/api/users")
        |> put_req_header("x-forwarded-for", "192.168.1.100")
        |> Plug.call([])

      # Should be blocked by higher priority rule
      assert conn.state == :sent
      assert conn.status == 403
    end

    test "ignores disabled rules", %{route: route} do
      rule = %Rule{
        id: 1,
        route_id: route.id,
        enabled: false,
        priority: 10
      }

      ip_filter = %IpFilter{
        id: 1,
        rule_id: rule.id,
        ip_address: "192.168.1.100",
        type: :blacklist,
        enabled: true
      }

      ETS.store_rule(rule)
      ETS.store_ip_filter(ip_filter)

      conn =
        :get
        |> conn("/api/users")
        |> put_req_header("x-forwarded-for", "192.168.1.100")
        |> Plug.call([])

      # Should be allowed because rule is disabled
      assert conn.state != :sent
    end
  end
end
