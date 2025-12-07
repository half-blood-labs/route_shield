defmodule RouteShield.Schema.Route do
  @moduledoc """
  Schema for discovered routes.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "route_shield_routes" do
    field :method, :string
    field :path_pattern, :string
    field :controller, :string
    field :action, :string
    field :helper, :string
    field :discovered_at, :utc_datetime

    timestamps()
  end

  def changeset(route, attrs) do
    route
    |> cast(attrs, [:method, :path_pattern, :controller, :action, :helper, :discovered_at])
    |> validate_required([:method, :path_pattern])
  end
end
