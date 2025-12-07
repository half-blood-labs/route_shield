defmodule RouteShield.Repo.Migrations.CreateRouteShieldRateLimits do
  use Ecto.Migration

  def change do
    create table(:route_shield_rate_limits) do
      add :rule_id, references(:route_shield_rules, on_delete: :delete_all), null: false
      add :requests_per_window, :integer, null: false
      add :window_seconds, :integer, null: false
      add :enabled, :boolean, default: true, null: false

      timestamps()
    end

    create index(:route_shield_rate_limits, [:rule_id])
    create index(:route_shield_rate_limits, [:enabled])
  end
end
