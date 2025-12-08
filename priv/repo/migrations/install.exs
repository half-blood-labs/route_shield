defmodule RouteShield.InstallMigration do
  @moduledoc """
  RouteShield installation migration.

  This migration creates all RouteShield tables. Copy this file to your
  project's migrations directory and run `mix ecto.migrate`.
  """

  use Ecto.Migration

  def up do
    # Create routes table
    create table(:route_shield_routes) do
      add :method, :string, null: false
      add :path_pattern, :string, null: false
      add :controller, :string
      add :action, :string
      add :helper, :string
      add :discovered_at, :utc_datetime

      timestamps()
    end

    create index(:route_shield_routes, [:method, :path_pattern], unique: true)
    create index(:route_shield_routes, [:controller, :action])

    # Create rules table
    create table(:route_shield_rules) do
      add :route_id, references(:route_shield_routes, on_delete: :delete_all), null: false
      add :enabled, :boolean, default: true, null: false
      add :priority, :integer, default: 0, null: false
      add :description, :string

      timestamps()
    end

    create index(:route_shield_rules, [:route_id])
    create index(:route_shield_rules, [:enabled])

    # Create rate limits table
    create table(:route_shield_rate_limits) do
      add :rule_id, references(:route_shield_rules, on_delete: :delete_all), null: false
      add :requests_per_window, :integer, null: false
      add :window_seconds, :integer, null: false
      add :enabled, :boolean, default: true, null: false

      timestamps()
    end

    create index(:route_shield_rate_limits, [:rule_id])
    create index(:route_shield_rate_limits, [:enabled])

    # Create IP filters table
    create table(:route_shield_ip_filters) do
      add :rule_id, references(:route_shield_rules, on_delete: :delete_all), null: false
      add :ip_address, :string, null: false
      add :type, :string, null: false  # whitelist or blacklist
      add :enabled, :boolean, default: true, null: false
      add :description, :string

      timestamps()
    end

    create index(:route_shield_ip_filters, [:rule_id])
    create index(:route_shield_ip_filters, [:type, :enabled])
    create index(:route_shield_ip_filters, [:ip_address])

    # Create time restrictions table
    create table(:route_shield_time_restrictions) do
      add :rule_id, references(:route_shield_rules, on_delete: :delete_all), null: false
      add :start_time, :time
      add :end_time, :time
      add :days_of_week, {:array, :integer}
      add :timezone, :string, default: "UTC", null: false
      add :enabled, :boolean, default: true, null: false

      timestamps()
    end

    create index(:route_shield_time_restrictions, [:rule_id])
    create index(:route_shield_time_restrictions, [:enabled])

    # Create concurrent limits table
    create table(:route_shield_concurrent_limits) do
      add :rule_id, references(:route_shield_rules, on_delete: :delete_all), null: false
      add :max_concurrent, :integer, default: 10, null: false
      add :enabled, :boolean, default: true, null: false

      timestamps()
    end

    create index(:route_shield_concurrent_limits, [:rule_id])
    create unique_index(:route_shield_concurrent_limits, [:rule_id])

    # Create custom responses table
    create table(:route_shield_custom_responses) do
      add :rule_id, references(:route_shield_rules, on_delete: :delete_all), null: false
      add :status_code, :integer, default: 403, null: false
      add :message, :text
      add :content_type, :string, default: "application/json", null: false
      add :enabled, :boolean, default: true, null: false

      timestamps()
    end

    create index(:route_shield_custom_responses, [:rule_id])
    create unique_index(:route_shield_custom_responses, [:rule_id])

    # Create global IP blacklist table
    create table(:route_shield_global_ip_blacklist) do
      add :ip_address, :string, null: false
      add :enabled, :boolean, default: true, null: false
      add :description, :string
      add :expires_at, :utc_datetime

      timestamps()
    end

    create index(:route_shield_global_ip_blacklist, [:ip_address])
    create index(:route_shield_global_ip_blacklist, [:enabled])
    create index(:route_shield_global_ip_blacklist, [:expires_at])
  end

  def down do
    drop table(:route_shield_global_ip_blacklist)
    drop table(:route_shield_custom_responses)
    drop table(:route_shield_concurrent_limits)
    drop table(:route_shield_time_restrictions)
    drop table(:route_shield_ip_filters)
    drop table(:route_shield_rate_limits)
    drop table(:route_shield_rules)
    drop table(:route_shield_routes)
  end
end
