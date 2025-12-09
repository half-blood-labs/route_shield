defmodule RouteShield.InstallMigration do
  @moduledoc """
  RouteShield installation migration.

  This migration creates all RouteShield tables. This migration is idempotent -
  you can re-run it to add any missing tables when RouteShield is updated.

  Copy this file to your project's migrations directory and run `mix ecto.migrate`.
  """

  use Ecto.Migration

  def up do
    # Helper function to create table only if it doesn't exist
    create_table_if_not_exists = fn table_name, columns_sql ->
      execute("CREATE TABLE IF NOT EXISTS " <> table_name <> " (" <> columns_sql <> ")")
    end

    # Create routes table (idempotent)
    create_table_if_not_exists.("route_shield_routes",
      "id BIGSERIAL PRIMARY KEY, " <>
      "method VARCHAR(255) NOT NULL, " <>
      "path_pattern VARCHAR(255) NOT NULL, " <>
      "controller VARCHAR(255), " <>
      "action VARCHAR(255), " <>
      "helper VARCHAR(255), " <>
      "discovered_at TIMESTAMP, " <>
      "inserted_at TIMESTAMP NOT NULL, " <>
      "updated_at TIMESTAMP NOT NULL")

    create_if_not_exists index(:route_shield_routes, [:method, :path_pattern], unique: true)
    create_if_not_exists index(:route_shield_routes, [:controller, :action])

    # Create rules table (idempotent)
    create_table_if_not_exists.("route_shield_rules",
      "id BIGSERIAL PRIMARY KEY, " <>
      "route_id BIGINT NOT NULL REFERENCES route_shield_routes(id) ON DELETE CASCADE, " <>
      "enabled BOOLEAN NOT NULL DEFAULT true, " <>
      "priority INTEGER NOT NULL DEFAULT 0, " <>
      "description VARCHAR(255), " <>
      "inserted_at TIMESTAMP NOT NULL, " <>
      "updated_at TIMESTAMP NOT NULL")

    create_if_not_exists index(:route_shield_rules, [:route_id])
    create_if_not_exists index(:route_shield_rules, [:enabled])

    # Create rate limits table (idempotent)
    create_table_if_not_exists.("route_shield_rate_limits",
      "id BIGSERIAL PRIMARY KEY, " <>
      "rule_id BIGINT NOT NULL REFERENCES route_shield_rules(id) ON DELETE CASCADE, " <>
      "requests_per_window INTEGER NOT NULL, " <>
      "window_seconds INTEGER NOT NULL, " <>
      "enabled BOOLEAN NOT NULL DEFAULT true, " <>
      "inserted_at TIMESTAMP NOT NULL, " <>
      "updated_at TIMESTAMP NOT NULL")

    create_if_not_exists index(:route_shield_rate_limits, [:rule_id])
    create_if_not_exists index(:route_shield_rate_limits, [:enabled])

    # Create IP filters table (idempotent)
    create_table_if_not_exists.("route_shield_ip_filters",
      "id BIGSERIAL PRIMARY KEY, " <>
      "rule_id BIGINT NOT NULL REFERENCES route_shield_rules(id) ON DELETE CASCADE, " <>
      "ip_address VARCHAR(255) NOT NULL, " <>
      "type VARCHAR(255) NOT NULL, " <>
      "enabled BOOLEAN NOT NULL DEFAULT true, " <>
      "description VARCHAR(255), " <>
      "inserted_at TIMESTAMP NOT NULL, " <>
      "updated_at TIMESTAMP NOT NULL")

    create_if_not_exists index(:route_shield_ip_filters, [:rule_id])
    create_if_not_exists index(:route_shield_ip_filters, [:type, :enabled])
    create_if_not_exists index(:route_shield_ip_filters, [:ip_address])

    # Create time restrictions table (idempotent)
    create_table_if_not_exists.("route_shield_time_restrictions",
      "id BIGSERIAL PRIMARY KEY, " <>
      "rule_id BIGINT NOT NULL REFERENCES route_shield_rules(id) ON DELETE CASCADE, " <>
      "start_time TIME, " <>
      "end_time TIME, " <>
      "days_of_week INTEGER[], " <>
      "timezone VARCHAR(255) NOT NULL DEFAULT 'UTC', " <>
      "enabled BOOLEAN NOT NULL DEFAULT true, " <>
      "inserted_at TIMESTAMP NOT NULL, " <>
      "updated_at TIMESTAMP NOT NULL")

    create_if_not_exists index(:route_shield_time_restrictions, [:rule_id])
    create_if_not_exists index(:route_shield_time_restrictions, [:enabled])

    # Create concurrent limits table (idempotent)
    create_table_if_not_exists.("route_shield_concurrent_limits",
      "id BIGSERIAL PRIMARY KEY, " <>
      "rule_id BIGINT NOT NULL REFERENCES route_shield_rules(id) ON DELETE CASCADE, " <>
      "max_concurrent INTEGER NOT NULL DEFAULT 10, " <>
      "enabled BOOLEAN NOT NULL DEFAULT true, " <>
      "inserted_at TIMESTAMP NOT NULL, " <>
      "updated_at TIMESTAMP NOT NULL, " <>
      "UNIQUE(rule_id)")

    create_if_not_exists index(:route_shield_concurrent_limits, [:rule_id])

    # Create custom responses table (idempotent)
    create_table_if_not_exists.("route_shield_custom_responses",
      "id BIGSERIAL PRIMARY KEY, " <>
      "rule_id BIGINT NOT NULL REFERENCES route_shield_rules(id) ON DELETE CASCADE, " <>
      "status_code INTEGER NOT NULL DEFAULT 403, " <>
      "message TEXT, " <>
      "content_type VARCHAR(255) NOT NULL DEFAULT 'application/json', " <>
      "enabled BOOLEAN NOT NULL DEFAULT true, " <>
      "inserted_at TIMESTAMP NOT NULL, " <>
      "updated_at TIMESTAMP NOT NULL, " <>
      "UNIQUE(rule_id)")

    create_if_not_exists index(:route_shield_custom_responses, [:rule_id])

    # Create global IP blacklist table (idempotent)
    create_table_if_not_exists.("route_shield_global_ip_blacklist",
      "id BIGSERIAL PRIMARY KEY, " <>
      "ip_address VARCHAR(255) NOT NULL, " <>
      "enabled BOOLEAN NOT NULL DEFAULT true, " <>
      "description VARCHAR(255), " <>
      "expires_at TIMESTAMP, " <>
      "inserted_at TIMESTAMP NOT NULL, " <>
      "updated_at TIMESTAMP NOT NULL")

    create_if_not_exists index(:route_shield_global_ip_blacklist, [:ip_address])
    create_if_not_exists index(:route_shield_global_ip_blacklist, [:enabled])
    create_if_not_exists index(:route_shield_global_ip_blacklist, [:expires_at])
  end

  def down do
    drop_if_exists table(:route_shield_global_ip_blacklist)
    drop_if_exists table(:route_shield_custom_responses)
    drop_if_exists table(:route_shield_concurrent_limits)
    drop_if_exists table(:route_shield_time_restrictions)
    drop_if_exists table(:route_shield_ip_filters)
    drop_if_exists table(:route_shield_rate_limits)
    drop_if_exists table(:route_shield_rules)
    drop_if_exists table(:route_shield_routes)
  end
end
