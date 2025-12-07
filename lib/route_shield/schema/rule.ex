defmodule RouteShield.Schema.Rule do
  @moduledoc """
  Schema for rule definitions.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "route_shield_rules" do
    field :route_id, :id
    field :enabled, :boolean, default: true
    field :priority, :integer, default: 0
    field :description, :string

    timestamps()
  end

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [:route_id, :enabled, :priority, :description])
    |> validate_required([:route_id])
  end
end
