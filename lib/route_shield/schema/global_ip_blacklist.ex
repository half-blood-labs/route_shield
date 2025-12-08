defmodule RouteShield.Schema.GlobalIpBlacklist do
  @moduledoc """
  Schema for global IP blacklist (applies to all routes).
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "route_shield_global_ip_blacklist" do
    field(:ip_address, :string)
    field(:enabled, :boolean, default: true)
    field(:description, :string)
    field(:expires_at, :utc_datetime)

    timestamps()
  end

  def changeset(global_ip_blacklist, attrs) do
    global_ip_blacklist
    |> cast(attrs, [:ip_address, :enabled, :description, :expires_at])
    |> validate_required([:ip_address])
  end
end
