defmodule RouteShield.Rules.TimeRestriction do
  @moduledoc """
  Time-based restriction checking (time windows, days of week).
  """

  alias RouteShield.Storage.ETS

  def check_time_access(rule_id) do
    time_restrictions = ETS.get_time_restrictions_for_rule(rule_id)

    if Enum.empty?(time_restrictions) do
      {:ok, :allowed}
    else
      now = get_current_time()

      allowed? =
        Enum.any?(time_restrictions, fn restriction ->
          check_restriction(restriction, now)
        end)

      if allowed? do
        {:ok, :allowed}
      else
        {:error, :time_restricted}
      end
    end
  end

  defp check_restriction(restriction, now) do
    # Check day of week (1 = Monday, 7 = Sunday)
    day_allowed? =
      if restriction.days_of_week && length(restriction.days_of_week) > 0 do
        day_of_week = Date.day_of_week(DateTime.to_date(now))
        day_of_week in restriction.days_of_week
      else
        true
      end

    # Check time window
    time_allowed? =
      if restriction.start_time && restriction.end_time do
        current_time = Time.new!(now.hour, now.minute, now.second)
        time_in_range?(current_time, restriction.start_time, restriction.end_time)
      else
        true
      end

    day_allowed? && time_allowed?
  end

  defp time_in_range?(current, start_time, end_time) do
    cond do
      Time.compare(start_time, end_time) == :lt ->
        # Normal case: start < end (e.g., 09:00 to 17:00)
        Time.compare(current, start_time) != :lt && Time.compare(current, end_time) != :gt

      Time.compare(start_time, end_time) == :gt ->
        # Wraps midnight: start > end (e.g., 22:00 to 06:00)
        Time.compare(current, start_time) != :lt || Time.compare(current, end_time) != :gt

      true ->
        # Equal times - allow all or block all? Let's allow
        true
    end
  end

  defp get_current_time do
    DateTime.utc_now()
  end
end
