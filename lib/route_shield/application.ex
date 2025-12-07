defmodule RouteShield.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    RouteShield.Storage.ETS.start_link()
    RouteShield.Rules.RateLimit.init()

    children = []

    opts = [strategy: :one_for_one, name: RouteShield.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
