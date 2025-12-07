defmodule RouteShield.Schema.RateLimit do
  @moduledoc """
  Schema for rate limit configurations.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "route_shield_rate_limits" do
    field(:rule_id, :id)
    field(:requests_per_window, :integer)
    field(:window_seconds, :integer)
    field(:enabled, :boolean, default: true)

    timestamps()
  end

  def changeset(rate_limit, attrs) do
    rate_limit
    |> cast(attrs, [:rule_id, :requests_per_window, :window_seconds, :enabled])
    |> validate_required([:rule_id, :requests_per_window, :window_seconds])
    |> validate_number(:requests_per_window, greater_than: 0)
    |> validate_number(:window_seconds, greater_than: 0)
  end
end
