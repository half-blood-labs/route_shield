defmodule RouteShield.Repo.Migrations.CreateRouteShieldTimeRestrictions do
  use Ecto.Migration

  def change do
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
  end
end
