defmodule RouteShield.Schema.TimeRestriction do
  @moduledoc """
  Schema for time-based restrictions.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "route_shield_time_restrictions" do
    field :rule_id, :id
    field :start_time, :time
    field :end_time, :time
    field :days_of_week, {:array, :integer}
    field :timezone, :string, default: "UTC"
    field :enabled, :boolean, default: true

    timestamps()
  end

  def changeset(time_restriction, attrs) do
    time_restriction
    |> cast(attrs, [:rule_id, :start_time, :end_time, :days_of_week, :timezone, :enabled])
    |> validate_required([:rule_id])
  end
end
