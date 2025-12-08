defmodule RouteShield.Schema.CustomResponse do
  @moduledoc """
  Schema for custom blocked response configuration per rule.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "route_shield_custom_responses" do
    field(:rule_id, :id)
    field(:status_code, :integer, default: 403)
    field(:message, :string)
    field(:content_type, :string, default: "application/json")
    field(:enabled, :boolean, default: true)

    timestamps()
  end

  def changeset(custom_response, attrs) do
    custom_response
    |> cast(attrs, [:rule_id, :status_code, :message, :content_type, :enabled])
    |> validate_required([:rule_id, :status_code])
    |> validate_inclusion(:status_code, [400, 401, 403, 404, 429, 503])
    |> validate_inclusion(:content_type, [
      "application/json",
      "application/xml",
      "text/html",
      "text/plain"
    ])
  end
end
