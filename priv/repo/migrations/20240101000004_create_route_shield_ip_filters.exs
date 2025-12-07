defmodule RouteShield.Repo.Migrations.CreateRouteShieldIpFilters do
  use Ecto.Migration

  def change do
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
  end
end
