defmodule RouteShield.Repo.Migrations.CreateRouteShieldRoutes do
  use Ecto.Migration

  def change do
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
  end
end
