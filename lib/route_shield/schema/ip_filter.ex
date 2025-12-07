defmodule RouteShield.Schema.IpFilter do
  @moduledoc """
  Schema for IP whitelist/blacklist entries.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "route_shield_ip_filters" do
    field :rule_id, :id
    field :ip_address, :string
    field :type, Ecto.Enum, values: [:whitelist, :blacklist]
    field :enabled, :boolean, default: true
    field :description, :string

    timestamps()
  end

  def changeset(ip_filter, attrs) do
    ip_filter
    |> cast(attrs, [:rule_id, :ip_address, :type, :enabled, :description])
    |> validate_required([:rule_id, :ip_address, :type])
    |> validate_inclusion(:type, [:whitelist, :blacklist])
  end
end
