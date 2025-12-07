defmodule RouteShield.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize ETS tables
    RouteShield.Storage.ETS.start_link()
    RouteShield.Rules.RateLimit.init()

    children = [
      # Starts a worker by calling: RouteShield.Worker.start_link(arg)
      # {RouteShield.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RouteShield.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
