# RouteShield Quick Start Guide

## Installation

1. Add to your `mix.exs`:

```elixir
defp deps do
  [
    {:route_shield, path: "../route_shield"}  # Or from hex when published
  ]
end
```

2. Install dependencies:

```bash
mix deps.get
```

## Setup

### 1. Configure

Add to `config/config.exs`:

```elixir
config :route_shield,
  repo: YourApp.Repo
```

### 2. Add to Router

```elixir
defmodule YourApp.Router do
  use YourApp, :router
  use RouteShield.Plug  # Add this for route discovery

  # ... your pipelines ...

  # Add dashboard route (optional, but recommended)
  scope "/admin" do
    pipe_through :browser
    live "/route_shield", RouteShield.DashboardLive
  end
end
```

### 3. Add Plug to Pipeline

Add the plug **before** authentication:

```elixir
pipeline :api do
  plug RouteShield.Plug  # Add here - before auth
  plug :accepts, ["json"]
  # ... other plugs including auth ...
end
```

### 4. Install Migrations

Generate and run the RouteShield migration:

```bash
mix route_shield.install
mix ecto.migrate
```

The `mix route_shield.install` command will generate a migration file in your
project's `priv/repo/migrations/` directory with all RouteShield tables.

### 5. Discover Routes

```bash
mix route_shield.discover YourApp.Router
```

Or programmatically:

```elixir
# In your application startup
RouteShield.discover_routes(YourApp.Router, YourApp.Repo)
```

## Usage

### Dashboard

Navigate to `/admin/route_shield` (or your configured path) to:
- View all discovered routes
- Create rules for routes
- Configure rate limits (per-IP)
- Manage IP whitelists/blacklists
- View real-time rule status

### Programmatic Usage

```elixir
# Discover routes
RouteShield.discover_routes(YourApp.Router, YourApp.Repo)

# Refresh cache after rule changes
RouteShield.refresh_cache(YourApp.Repo)
```

## Features

### Rate Limiting
- Per-IP token bucket algorithm
- Configurable requests per time window
- Automatic cleanup of old buckets

### IP Filtering
- Whitelist: Only allow specific IPs
- Blacklist: Block specific IPs
- CIDR notation support (e.g., `192.168.1.0/24`)

### Rules
- Multiple rules per route
- Priority-based rule application
- Enable/disable rules dynamically

## Notes

- Routes are discovered at compile-time and stored in database + ETS
- Rules are stored in database and cached in ETS for fast lookups
- Cache is automatically refreshed when rules change via dashboard
- The plug should be placed **before** authentication for maximum protection
