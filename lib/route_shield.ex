defmodule RouteShield do
  @moduledoc """
  RouteShield - Route protection and access control for Phoenix applications.

  ## Setup

  1. Add to your router:

  ```elixir
  defmodule MyApp.Router do
    use MyApp, :router
    use RouteShield.Plug

    live "/route_shield", RouteShield.DashboardLive
  end
  ```

  2. Add plug to pipeline (before authentication):

  ```elixir
  pipeline :api do
    plug RouteShield.Plug
  end
  ```

  3. Configure:

  ```elixir
  config :route_shield,
    repo: MyApp.Repo
  ```

  4. Run migrations and discover routes:

  ```elixir
  RouteShield.discover_routes(MyApp.Router, MyApp.Repo)
  ```
  """

  alias RouteShield.RouteDiscovery
  alias RouteShield.Storage.Cache

  @doc """
  Discovers routes from the router and stores them in database and ETS.
  Should be called at application startup or via a mix task.
  """
  def discover_routes(router_module, repo) do
    RouteDiscovery.discover_and_store_routes(router_module, repo)
  end

  @doc """
  Refreshes the ETS cache from the database.
  Call this after making rule changes via the dashboard.
  """
  def refresh_cache(repo) do
    Cache.refresh_all(repo)
  end
end
