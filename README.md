# RouteShield

A powerful Phoenix/Elixir plug that provides route discovery, rule-based request filtering, and a beautiful LiveView dashboard for managing route access controls.

## Overview

RouteShield is a comprehensive solution for managing and protecting your Phoenix application routes. It automatically discovers all routes at compile-time, stores them efficiently in ETS, and provides a real-time dashboard for configuring access rules. The plug enforces these rules before authentication, making it perfect for rate limiting, IP filtering, and advanced access control.

## Core Architecture

### 1. Route Discovery (Compile-Time)
- Uses `@before_compile` hook to introspect Phoenix router
- Extracts all routes (method, path pattern, controller, action)
- Populates ETS table on application startup
- Routes stored as: `{method, path_pattern, controller, action}`

### 2. Storage Strategy
- **Routes**: ETS only (read-only, compile-time populated)
- **Rules**: PostgreSQL (persistent) + ETS cache (hot reload on changes)
- Cache invalidation: When rules change in dashboard → update DB → refresh ETS

### 3. Dashboard Integration
- Phoenix LiveView with Tailwind CSS
- User adds route in router: `live "/admin/route_shield", RouteShield.DashboardLive`
- Similar to Oban's dashboard pattern
- Serves on user-defined path (default: `/route_shield`)

### 4. Plug Pipeline
```
Request → RouteShield Plug (checks rules) → Auth Plug → Controller
```

## Features

### MVP Features

#### 1. Route Discovery
- ✅ Automatic compile-time route discovery
- ✅ ETS storage for fast route lookups
- ✅ Support for dynamic routes (`/users/:id`)
- ✅ Display all routes in dashboard

#### 2. Rate Limiting
- ✅ Per-IP rate limiting
- ✅ Configurable requests per time window (e.g., 5 requests per second)
- ✅ Token bucket algorithm
- ✅ ETS-based counter storage with cleanup
- ✅ Customizable rate limit per route

#### 3. IP Whitelist
- ✅ Per-route IP whitelisting
- ✅ Support for CIDR notation (e.g., `192.168.1.0/24`)
- ✅ Multiple IPs per route
- ✅ Real-time enable/disable

#### 4. Dashboard
- ✅ Beautiful Tailwind CSS interface
- ✅ Real-time route listing
- ✅ Rule configuration UI
- ✅ Live updates (no page refresh needed)
- ✅ User-configurable dashboard route

### Advanced Features (Phase 2)

#### 5. IP Blacklist
- Per-route IP blacklisting
- Global IP blacklist
- Support for CIDR notation
- Temporary/permanent blocks

#### 6. Concurrent Request Limits
- Maximum simultaneous connections per IP
- Per-route configuration
- Prevents connection exhaustion attacks

#### 7. Custom Blocked Responses
- Customizable HTTP status codes
- Custom error messages
- JSON/HTML response formats
- Per-route response configuration

#### 8. Time-Based Restrictions
- Time window restrictions (e.g., only 9 AM–5 PM)
- Day-of-week restrictions (e.g., block weekends)
- Timezone support
- Per-route configuration

### Future Features (Phase 3)

#### 9. Geographic Restrictions
- Country-based blocking/allowing
- IP geolocation integration
- Per-route configuration

#### 10. Request Pattern Matching
- Block suspicious URL patterns
- Regex-based pattern matching
- Custom rule conditions

#### 11. Advanced Logging & Analytics
- Request/block logging
- Real-time statistics (requests/sec, blocked count)
- Historical data visualization
- Export capabilities

#### 12. Additional Security Features
- User agent blocking (block bots/scrapers)
- API key validation (require custom header)
- Custom header requirements
- Request size limits
- Maintenance mode per route
- Rule priority/ordering
- Bypass rules for specific conditions (e.g., internal IPs)

## Technical Decisions

### Rate Limiting
- **Algorithm**: Token bucket
- **Scope**: Per-IP (not per-route globally)
- **Storage**: ETS with automatic cleanup process
- **Window**: Configurable (seconds, minutes, hours)

### Route Matching
- Uses Phoenix's built-in route matching
- Handles dynamic segments (`/users/:id`)
- Pattern matching for rule application

### Database Schema
- **Normalized design**:
  - `route_shield_routes` - Discovered routes (read-only)
  - `route_shield_rules` - Rule definitions
  - `route_shield_rate_limits` - Rate limit configurations
  - `route_shield_ip_filters` - IP whitelist/blacklist entries
  - `route_shield_time_restrictions` - Time-based rules
  - Additional tables for future features

### Performance
- ETS for hot path (route matching, rule lookup)
- Database for persistence only
- Background process for ETS cache refresh
- Minimal overhead on request path

## Installation

```elixir
# mix.exs
defp deps do
  [
    {:route_shield, "~> 0.1.0"}
  ]
end
```

## Setup

### 1. Add to Router

```elixir
defmodule MyApp.Router do
  use MyApp, :router
  use RouteShield.Plug  # Add this

  # ... your routes ...

  # Add dashboard route
  live "/route_shield", RouteShield.DashboardLive
end
```

### 2. Run Migrations

```bash
mix ecto.gen.migration add_route_shield_tables
mix ecto.migrate
```

### 3. Configure

```elixir
# config/config.exs
config :route_shield,
  repo: MyApp.Repo,
  dashboard_route: "/route_shield"  # Optional, defaults to "/route_shield"
```

## Usage

### In Router

```elixir
defmodule MyApp.Router do
  use MyApp, :router
  use RouteShield.Plug

  pipeline :api do
    plug RouteShield.Plug  # Add before authentication
    plug :accepts, ["json"]
    # ... other plugs including auth ...
  end
end
```

### Dashboard

Navigate to `/route_shield` (or your configured path) to:
- View all discovered routes
- Configure rate limits per route
- Manage IP whitelists/blacklists
- Set time-based restrictions
- View real-time statistics

## Project Structure

```
route_shield/
├── lib/
│   ├── route_shield/
│   │   ├── plug.ex              # Main plug for enforcement
│   │   ├── router.ex             # Compile-time route discovery
│   │   ├── dashboard_live.ex     # LiveView dashboard
│   │   ├── rules/
│   │   │   ├── rate_limit.ex    # Rate limiting logic
│   │   │   ├── ip_filter.ex     # IP whitelist/blacklist
│   │   │   └── time_restriction.ex
│   │   ├── storage/
│   │   │   ├── ets.ex           # ETS operations
│   │   │   └── cache.ex         # Cache refresh logic
│   │   └── schema.ex            # Database schemas
│   └── route_shield.ex
├── priv/
│   └── repo/
│       └── migrations/          # Ecto migrations
└── mix.exs
```

## License

MIT
