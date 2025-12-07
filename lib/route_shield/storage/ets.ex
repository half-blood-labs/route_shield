defmodule RouteShield.Storage.ETS do
  @moduledoc """
  ETS table management for routes and rules cache.
  Provides fast in-memory lookups for route matching and rule enforcement.
  """

  @routes_table :route_shield_routes
  @rules_table :route_shield_rules
  @rate_limits_table :route_shield_rate_limits
  @ip_filters_table :route_shield_ip_filters
  @time_restrictions_table :route_shield_time_restrictions

  def start_link do
    # Create ETS tables
    :ets.new(@routes_table, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(@rules_table, [:named_table, :bag, :public, read_concurrency: true])
    :ets.new(@rate_limits_table, [:named_table, :bag, :public, read_concurrency: true])
    :ets.new(@ip_filters_table, [:named_table, :bag, :public, read_concurrency: true])
    :ets.new(@time_restrictions_table, [:named_table, :bag, :public, read_concurrency: true])

    :ok
  end

  # Route operations
  def store_route(route) do
    key = {route.method, route.path_pattern}
    # Store both by key and by ID if available
    :ets.insert(@routes_table, {key, route})
    if Map.has_key?(route, :id) and route.id do
      :ets.insert(@routes_table, {route.id, route})
    end
  end

  def get_route(method, path_pattern) do
    case :ets.lookup(@routes_table, {method, path_pattern}) do
      [{_, route}] -> {:ok, route}
      [] -> {:error, :not_found}
    end
  end

  def get_route_by_id(id) do
    case :ets.lookup(@routes_table, id) do
      [{_, route}] -> {:ok, route}
      [] -> {:error, :not_found}
    end
  end

  def list_routes do
    @routes_table
    |> :ets.tab2list()
    |> Enum.map(fn {key, route} -> route end)
    |> Enum.uniq_by(&{&1.method, &1.path_pattern})
  end

  def clear_routes do
    :ets.delete_all_objects(@routes_table)
  end

  # Rule operations
  def store_rule(rule) do
    :ets.insert(@rules_table, {rule.route_id, rule})
  end

  def get_rules_for_route(route_id) do
    @rules_table
    |> :ets.lookup(route_id)
    |> Enum.map(fn {_key, rule} -> rule end)
    |> Enum.filter(& &1.enabled)
    |> Enum.sort_by(& &1.priority, :desc)
  end

  def clear_rules do
    :ets.delete_all_objects(@rules_table)
  end

  # Rate limit operations
  def store_rate_limit(rate_limit) do
    :ets.insert(@rate_limits_table, {rate_limit.rule_id, rate_limit})
  end

  def get_rate_limit_for_rule(rule_id) do
    case :ets.lookup(@rate_limits_table, rule_id) do
      [{_, rate_limit}] when rate_limit.enabled -> {:ok, rate_limit}
      _ -> {:error, :not_found}
    end
  end

  def clear_rate_limits do
    :ets.delete_all_objects(@rate_limits_table)
  end

  # IP filter operations
  def store_ip_filter(ip_filter) do
    :ets.insert(@ip_filters_table, {ip_filter.rule_id, ip_filter})
  end

  def get_ip_filters_for_rule(rule_id) do
    @ip_filters_table
    |> :ets.lookup(rule_id)
    |> Enum.map(fn {_key, filter} -> filter end)
    |> Enum.filter(& &1.enabled)
  end

  def clear_ip_filters do
    :ets.delete_all_objects(@ip_filters_table)
  end

  # Time restriction operations
  def store_time_restriction(time_restriction) do
    :ets.insert(@time_restrictions_table, {time_restriction.rule_id, time_restriction})
  end

  def get_time_restrictions_for_rule(rule_id) do
    @time_restrictions_table
    |> :ets.lookup(rule_id)
    |> Enum.map(fn {_key, restriction} -> restriction end)
    |> Enum.filter(& &1.enabled)
  end

  def clear_time_restrictions do
    :ets.delete_all_objects(@time_restrictions_table)
  end

  # Clear all tables
  def clear_all do
    clear_routes()
    clear_rules()
    clear_rate_limits()
    clear_ip_filters()
    clear_time_restrictions()
  end
end
