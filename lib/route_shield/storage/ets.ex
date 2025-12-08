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
  @concurrent_limits_table :route_shield_concurrent_limits
  @custom_responses_table :route_shield_custom_responses
  @global_blacklist_table :route_shield_global_ip_blacklist

  def start_link do
    :ets.new(@routes_table, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(@rules_table, [:named_table, :bag, :public, read_concurrency: true])
    :ets.new(@rate_limits_table, [:named_table, :bag, :public, read_concurrency: true])
    :ets.new(@ip_filters_table, [:named_table, :bag, :public, read_concurrency: true])
    :ets.new(@time_restrictions_table, [:named_table, :bag, :public, read_concurrency: true])
    :ets.new(@concurrent_limits_table, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(@custom_responses_table, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(@global_blacklist_table, [:named_table, :bag, :public, read_concurrency: true])

    :ok
  end

  def store_route(route) do
    key = {route.method, route.path_pattern}
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
    |> Enum.map(fn {_key, route} -> route end)
    |> Enum.uniq_by(&{&1.method, &1.path_pattern})
  end

  def clear_routes do
    :ets.delete_all_objects(@routes_table)
  end

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

  def store_concurrent_limit(concurrent_limit) do
    :ets.insert(@concurrent_limits_table, {concurrent_limit.rule_id, concurrent_limit})
  end

  def get_concurrent_limit_for_rule(rule_id) do
    case :ets.lookup(@concurrent_limits_table, rule_id) do
      [{_, limit}] when limit.enabled -> {:ok, limit}
      _ -> {:error, :not_found}
    end
  end

  def clear_concurrent_limits do
    :ets.delete_all_objects(@concurrent_limits_table)
  end

  def store_custom_response(custom_response) do
    :ets.insert(@custom_responses_table, {custom_response.rule_id, custom_response})
  end

  def get_custom_response_for_rule(rule_id) do
    case :ets.lookup(@custom_responses_table, rule_id) do
      [{_, response}] when response.enabled -> {:ok, response}
      _ -> {:error, :not_found}
    end
  end

  def clear_custom_responses do
    :ets.delete_all_objects(@custom_responses_table)
  end

  def store_global_blacklist_entry(entry) do
    :ets.insert(@global_blacklist_table, {entry.ip_address, entry})
  end

  def get_global_blacklist_entries do
    @global_blacklist_table
    |> :ets.tab2list()
    |> Enum.map(fn {_key, entry} -> entry end)
    |> Enum.filter(& &1.enabled)
    |> Enum.filter(fn entry ->
      if entry.expires_at do
        DateTime.compare(DateTime.utc_now(), entry.expires_at) == :lt
      else
        true
      end
    end)
  end

  def clear_global_blacklist do
    :ets.delete_all_objects(@global_blacklist_table)
  end

  def clear_all do
    clear_routes()
    clear_rules()
    clear_rate_limits()
    clear_ip_filters()
    clear_time_restrictions()
    clear_concurrent_limits()
    clear_custom_responses()
    clear_global_blacklist()
  end
end
