defmodule RouteShield.Rules.ConcurrentLimit do
  @moduledoc """
  Concurrent request limit enforcement per IP.
  Tracks active connections per IP and blocks when limit is exceeded.
  """

  @active_connections_table :route_shield_active_connections

  def init do
    :ets.new(@active_connections_table, [:named_table, :bag, :public])
    :ok
  end

  def check_concurrent_limit(ip_address, rule_id, max_concurrent) do
    key = {ip_address, rule_id}
    active_count = count_active_connections(key)

    if active_count >= max_concurrent do
      {:error, :concurrent_limit_exceeded}
    else
      {:ok, :allowed}
    end
  end

  def track_connection(ip_address, rule_id) do
    key = {ip_address, rule_id}
    connection_id = make_ref()
    :ets.insert(@active_connections_table, {key, connection_id})
    connection_id
  end

  def release_connection(ip_address, rule_id, connection_id) do
    key = {ip_address, rule_id}
    :ets.match_delete(@active_connections_table, {key, connection_id})
  end

  defp count_active_connections(key) do
    @active_connections_table
    |> :ets.lookup(key)
    |> length()
  end

  def cleanup_old_connections do
    # In a production system, you might want to add timestamps
    # and clean up stale connections. For now, connections are
    # released when requests complete.
    :ok
  end
end
