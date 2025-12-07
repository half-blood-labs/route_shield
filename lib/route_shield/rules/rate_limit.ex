defmodule RouteShield.Rules.RateLimit do
  @moduledoc """
  Token bucket rate limiting implementation (per-IP).
  """

  alias RouteShield.Storage.ETS

  @rate_limit_buckets_table :route_shield_rate_limit_buckets

  def init do
    :ets.new(@rate_limit_buckets_table, [
      :named_table,
      :set,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])
  end

  def check_rate_limit(ip_address, rule_id, rate_limit_config) do
    key = {ip_address, rule_id}
    now = System.system_time(:second)

    case :ets.lookup(@rate_limit_buckets_table, key) do
      [] ->
        # First request - create bucket
        create_bucket(key, rate_limit_config, now)
        {:ok, :allowed}

      [{^key, tokens, last_refill, window_seconds}] ->
        # Refill tokens based on time passed
        tokens_after_refill = refill_tokens(tokens, last_refill, now, window_seconds, rate_limit_config.requests_per_window)

        if tokens_after_refill >= 1 do
          # Allow request, consume token
          new_tokens = tokens_after_refill - 1
          :ets.insert(@rate_limit_buckets_table, {key, new_tokens, now, window_seconds})
          {:ok, :allowed}
        else
          # Rate limit exceeded
          {:error, :rate_limit_exceeded}
        end
    end
  end

  defp create_bucket(key, rate_limit_config, now) do
    initial_tokens = rate_limit_config.requests_per_window - 1
    :ets.insert(@rate_limit_buckets_table, {
      key,
      initial_tokens,
      now,
      rate_limit_config.window_seconds
    })
  end

  defp refill_tokens(current_tokens, last_refill, now, window_seconds, max_tokens) do
    time_passed = now - last_refill

    if time_passed >= window_seconds do
      # Full window passed, reset to max
      max_tokens
    else
      # Calculate tokens to add based on time passed
      tokens_to_add = div(time_passed * max_tokens, window_seconds)
      min(current_tokens + tokens_to_add, max_tokens)
    end
  end

  # Cleanup old buckets (can be called periodically)
  def cleanup_old_buckets(rule_id, window_seconds) do
    cutoff_time = System.system_time(:second) - window_seconds * 2

    @rate_limit_buckets_table
    |> :ets.match({{{:_, ^rule_id}, :_, :"$1", :_}})
    |> Enum.each(fn [[last_refill]] ->
      if last_refill < cutoff_time do
        # Match and delete all buckets for this rule
        :ets.match_delete(@rate_limit_buckets_table, {{:_, rule_id}, :_, :_, :_})
      end
    end)
  end

  # Cleanup all old buckets (general cleanup)
  def cleanup_all_old_buckets(max_age_seconds \\ 3600) do
    cutoff_time = System.system_time(:second) - max_age_seconds

    @rate_limit_buckets_table
    |> :ets.select([{{:"$1", :"$2", :"$3", :_}, [{:<, :"$3", cutoff_time}], [:"$1"]}])
    |> Enum.each(fn key -> :ets.delete(@rate_limit_buckets_table, key) end)
  end
end
