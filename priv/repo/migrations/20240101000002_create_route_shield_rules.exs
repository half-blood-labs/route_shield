defmodule RouteShield.Repo.Migrations.CreateRouteShieldRules do
  use Ecto.Migration

  def change do
    create table(:route_shield_rules) do
      add :route_id, references(:route_shield_routes, on_delete: :delete_all), null: false
      add :enabled, :boolean, default: true, null: false
      add :priority, :integer, default: 0, null: false
      add :description, :string

      timestamps()
    end

    create index(:route_shield_rules, [:route_id])
    create index(:route_shield_rules, [:enabled])
  end
end
