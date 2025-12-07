defmodule RouteShield.Storage.Cache do
  @moduledoc """
  Cache refresh mechanism that loads rules from database into ETS.
  """

  import Ecto.Query
  alias RouteShield.Storage.ETS
  alias RouteShield.Schema.{Rule, RateLimit, IpFilter, TimeRestriction}

  def refresh_all(repo) do
    # Clear existing cache
    ETS.clear_all()

    # Load routes (these are populated at compile-time, but we refresh rules)
    refresh_rules(repo)
    refresh_rate_limits(repo)
    refresh_ip_filters(repo)
    refresh_time_restrictions(repo)

    :ok
  end

  def refresh_rules(repo) do
    repo.all(Rule)
    |> Enum.each(&ETS.store_rule/1)
  end

  def refresh_rate_limits(repo) do
    repo.all(RateLimit)
    |> Enum.each(&ETS.store_rate_limit/1)
  end

  def refresh_ip_filters(repo) do
    repo.all(IpFilter)
    |> Enum.each(&ETS.store_ip_filter/1)
  end

  def refresh_time_restrictions(repo) do
    repo.all(TimeRestriction)
    |> Enum.each(&ETS.store_time_restriction/1)
  end

  # Refresh specific rule and its related data
  def refresh_rule(repo, rule_id) do
    # Refresh rule
    case repo.get(Rule, rule_id) do
      nil -> :ok
      rule -> ETS.store_rule(rule)
    end

    # Refresh related data
    refresh_rate_limits_for_rule(repo, rule_id)
    refresh_ip_filters_for_rule(repo, rule_id)
    refresh_time_restrictions_for_rule(repo, rule_id)
  end

  defp refresh_rate_limits_for_rule(repo, rule_id) do
    repo.all(from rl in RateLimit, where: rl.rule_id == ^rule_id)
    |> Enum.each(&ETS.store_rate_limit/1)
  end

  defp refresh_ip_filters_for_rule(repo, rule_id) do
    repo.all(from ipf in IpFilter, where: ipf.rule_id == ^rule_id)
    |> Enum.each(&ETS.store_ip_filter/1)
  end

  defp refresh_time_restrictions_for_rule(repo, rule_id) do
    repo.all(from tr in TimeRestriction, where: tr.rule_id == ^rule_id)
    |> Enum.each(&ETS.store_time_restriction/1)
  end
end
