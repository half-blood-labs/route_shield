defmodule RouteShield.Storage.ETSTest do
  use ExUnit.Case

  alias RouteShield.Storage.ETS
  alias RouteShield.Schema.{Route, Rule, RateLimit, IpFilter, TimeRestriction}

  setup do
    ETS.clear_all()
    :ok
  end

  describe "routes" do
    test "store_route/1 stores route with method and path pattern" do
      route = %Route{
        id: 1,
        method: "GET",
        path_pattern: "/api/users",
        controller: "UserController",
        action: "index",
        discovered_at: DateTime.utc_now()
      }

      ETS.store_route(route)

      assert {:ok, stored_route} = ETS.get_route("GET", "/api/users")
      assert stored_route.id == 1
      assert stored_route.method == "GET"
    end

    test "store_route/1 stores route with ID as key" do
      route = %Route{
        id: 1,
        method: "GET",
        path_pattern: "/api/users",
        discovered_at: DateTime.utc_now()
      }

      ETS.store_route(route)

      assert {:ok, stored_route} = ETS.get_route_by_id(1)
      assert stored_route.id == 1
    end

    test "get_route/2 returns error when route not found" do
      assert {:error, :not_found} = ETS.get_route("POST", "/unknown")
    end

    test "list_routes/0 returns all unique routes" do
      route1 = %Route{
        id: 1,
        method: "GET",
        path_pattern: "/api/users",
        discovered_at: DateTime.utc_now()
      }

      route2 = %Route{
        id: 2,
        method: "POST",
        path_pattern: "/api/users",
        discovered_at: DateTime.utc_now()
      }

      ETS.store_route(route1)
      ETS.store_route(route2)

      routes = ETS.list_routes()
      assert length(routes) == 2
    end

    test "clear_routes/0 removes all routes" do
      route = %Route{
        id: 1,
        method: "GET",
        path_pattern: "/api/users",
        discovered_at: DateTime.utc_now()
      }

      ETS.store_route(route)
      ETS.clear_routes()

      assert {:error, :not_found} = ETS.get_route("GET", "/api/users")
      assert [] = ETS.list_routes()
    end
  end

  describe "rules" do
    test "store_rule/1 and get_rules_for_route/1" do
      rule = %Rule{
        id: 1,
        route_id: 10,
        enabled: true,
        priority: 5,
        description: "Test rule"
      }

      ETS.store_rule(rule)

      rules = ETS.get_rules_for_route(10)
      assert length(rules) == 1
      assert hd(rules).id == 1
    end

    test "get_rules_for_route/1 filters disabled rules" do
      enabled_rule = %Rule{
        id: 1,
        route_id: 10,
        enabled: true,
        priority: 5
      }

      disabled_rule = %Rule{
        id: 2,
        route_id: 10,
        enabled: false,
        priority: 5
      }

      ETS.store_rule(enabled_rule)
      ETS.store_rule(disabled_rule)

      rules = ETS.get_rules_for_route(10)
      assert length(rules) == 1
      assert hd(rules).id == 1
    end

    test "get_rules_for_route/1 sorts by priority descending" do
      rule1 = %Rule{id: 1, route_id: 10, enabled: true, priority: 5}
      rule2 = %Rule{id: 2, route_id: 10, enabled: true, priority: 10}
      rule3 = %Rule{id: 3, route_id: 10, enabled: true, priority: 1}

      ETS.store_rule(rule1)
      ETS.store_rule(rule2)
      ETS.store_rule(rule3)

      rules = ETS.get_rules_for_route(10)
      assert length(rules) == 3
      assert hd(rules).priority == 10
      assert List.last(rules).priority == 1
    end

    test "clear_rules/0 removes all rules" do
      rule = %Rule{id: 1, route_id: 10, enabled: true, priority: 5}
      ETS.store_rule(rule)
      ETS.clear_rules()

      assert [] = ETS.get_rules_for_route(10)
    end
  end

  describe "rate_limits" do
    test "store_rate_limit/1 and get_rate_limit_for_rule/1" do
      rate_limit = %RateLimit{
        id: 1,
        rule_id: 10,
        requests_per_window: 100,
        window_seconds: 60,
        enabled: true
      }

      ETS.store_rate_limit(rate_limit)

      assert {:ok, stored} = ETS.get_rate_limit_for_rule(10)
      assert stored.rule_id == 10
      assert stored.requests_per_window == 100
    end

    test "get_rate_limit_for_rule/1 returns error when not found" do
      assert {:error, :not_found} = ETS.get_rate_limit_for_rule(999)
    end

    test "get_rate_limit_for_rule/1 filters disabled rate limits" do
      rate_limit = %RateLimit{
        id: 1,
        rule_id: 10,
        requests_per_window: 100,
        window_seconds: 60,
        enabled: false
      }

      ETS.store_rate_limit(rate_limit)

      assert {:error, :not_found} = ETS.get_rate_limit_for_rule(10)
    end

    test "clear_rate_limits/0 removes all rate limits" do
      rate_limit = %RateLimit{
        id: 1,
        rule_id: 10,
        requests_per_window: 100,
        window_seconds: 60,
        enabled: true
      }

      ETS.store_rate_limit(rate_limit)
      ETS.clear_rate_limits()

      assert {:error, :not_found} = ETS.get_rate_limit_for_rule(10)
    end
  end

  describe "ip_filters" do
    test "store_ip_filter/1 and get_ip_filters_for_rule/1" do
      ip_filter = %IpFilter{
        id: 1,
        rule_id: 10,
        ip_address: "192.168.1.100",
        type: :blacklist,
        enabled: true
      }

      ETS.store_ip_filter(ip_filter)

      filters = ETS.get_ip_filters_for_rule(10)
      assert length(filters) == 1
      assert hd(filters).ip_address == "192.168.1.100"
    end

    test "get_ip_filters_for_rule/1 filters disabled filters" do
      enabled_filter = %IpFilter{
        id: 1,
        rule_id: 10,
        ip_address: "192.168.1.100",
        type: :blacklist,
        enabled: true
      }

      disabled_filter = %IpFilter{
        id: 2,
        rule_id: 10,
        ip_address: "192.168.1.200",
        type: :blacklist,
        enabled: false
      }

      ETS.store_ip_filter(enabled_filter)
      ETS.store_ip_filter(disabled_filter)

      filters = ETS.get_ip_filters_for_rule(10)
      assert length(filters) == 1
      assert hd(filters).id == 1
    end

    test "clear_ip_filters/0 removes all ip filters" do
      ip_filter = %IpFilter{
        id: 1,
        rule_id: 10,
        ip_address: "192.168.1.100",
        type: :blacklist,
        enabled: true
      }

      ETS.store_ip_filter(ip_filter)
      ETS.clear_ip_filters()

      assert [] = ETS.get_ip_filters_for_rule(10)
    end
  end

  describe "time_restrictions" do
    test "store_time_restriction/1 and get_time_restrictions_for_rule/1" do
      time_restriction = %TimeRestriction{
        id: 1,
        rule_id: 10,
        days_of_week: [1, 2, 3],
        start_time: ~T[09:00:00],
        end_time: ~T[17:00:00],
        enabled: true
      }

      ETS.store_time_restriction(time_restriction)

      restrictions = ETS.get_time_restrictions_for_rule(10)
      assert length(restrictions) == 1
      assert hd(restrictions).days_of_week == [1, 2, 3]
    end

    test "get_time_restrictions_for_rule/1 filters disabled restrictions" do
      enabled = %TimeRestriction{
        id: 1,
        rule_id: 10,
        days_of_week: [1, 2, 3],
        start_time: ~T[09:00:00],
        end_time: ~T[17:00:00],
        enabled: true
      }

      disabled = %TimeRestriction{
        id: 2,
        rule_id: 10,
        days_of_week: [4, 5],
        start_time: ~T[09:00:00],
        end_time: ~T[17:00:00],
        enabled: false
      }

      ETS.store_time_restriction(enabled)
      ETS.store_time_restriction(disabled)

      restrictions = ETS.get_time_restrictions_for_rule(10)
      assert length(restrictions) == 1
      assert hd(restrictions).id == 1
    end

    test "clear_time_restrictions/0 removes all time restrictions" do
      time_restriction = %TimeRestriction{
        id: 1,
        rule_id: 10,
        days_of_week: [1, 2, 3],
        start_time: ~T[09:00:00],
        end_time: ~T[17:00:00],
        enabled: true
      }

      ETS.store_time_restriction(time_restriction)
      ETS.clear_time_restrictions()

      assert [] = ETS.get_time_restrictions_for_rule(10)
    end
  end

  describe "clear_all/0" do
    test "clears all ETS tables" do
      route = %Route{
        id: 1,
        method: "GET",
        path_pattern: "/test",
        discovered_at: DateTime.utc_now()
      }

      rule = %Rule{id: 1, route_id: 1, enabled: true, priority: 5}

      rate_limit = %RateLimit{
        id: 1,
        rule_id: 1,
        requests_per_window: 100,
        window_seconds: 60,
        enabled: true
      }

      ip_filter = %IpFilter{
        id: 1,
        rule_id: 1,
        ip_address: "192.168.1.100",
        type: :blacklist,
        enabled: true
      }

      ETS.store_route(route)
      ETS.store_rule(rule)
      ETS.store_rate_limit(rate_limit)
      ETS.store_ip_filter(ip_filter)

      ETS.clear_all()

      assert {:error, :not_found} = ETS.get_route("GET", "/test")
      assert [] = ETS.get_rules_for_route(1)
      assert {:error, :not_found} = ETS.get_rate_limit_for_rule(1)
      assert [] = ETS.get_ip_filters_for_rule(1)
    end
  end
end
