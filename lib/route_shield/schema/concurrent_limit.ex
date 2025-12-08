defmodule RouteShield.Schema.ConcurrentLimit do
  @moduledoc """
  Schema for concurrent request limits per rule.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "route_shield_concurrent_limits" do
    field(:rule_id, :id)
    field(:max_concurrent, :integer, default: 10)
    field(:enabled, :boolean, default: true)

    timestamps()
  end

  def changeset(concurrent_limit, attrs) do
    concurrent_limit
    |> cast(attrs, [:rule_id, :max_concurrent, :enabled])
    |> validate_required([:rule_id, :max_concurrent])
    |> validate_number(:max_concurrent, greater_than: 0)
  end
end
