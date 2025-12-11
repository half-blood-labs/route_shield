<div align="center">

<svg width="250" height="250" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg" style="filter: drop-shadow(0 4px 8px rgba(0, 0, 0, 0.15));">
  <defs>
    <linearGradient id="shieldGradient" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#3B82F6;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#1E40AF;stop-opacity:1" />
    </linearGradient>
  </defs>
  <path d="M100 20 L40 45 L40 90 C40 130 60 165 100 180 C140 165 160 130 160 90 L160 45 Z" fill="url(#shieldGradient)" stroke="#1E3A8A" stroke-width="3" stroke-linejoin="round"/>
  <path d="M100 70 L80 85 L100 100 L120 85 Z" fill="white" opacity="0.9"/>
  <circle cx="100" cy="120" r="8" fill="white" opacity="0.9"/>
</svg>

# 🛡️ RouteShield

**A powerful Phoenix/Elixir plug that provides route discovery, rule-based request filtering, and a beautiful LiveView dashboard for managing route access controls.**

[![Hex.pm](https://img.shields.io/hexpm/v/route_shield.svg)](https://hex.pm/packages/route_shield)
[![Hex.pm](https://img.shields.io/hexpm/dt/route_shield.svg)](https://hex.pm/packages/route_shield)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Elixir](https://img.shields.io/badge/elixir-~%3E%201.16-blue.svg)](https://elixir-lang.org/)

</div>

## Overview

RouteShield is a comprehensive solution for managing and protecting your Phoenix application routes. It automatically discovers all routes at compile-time, stores them efficiently in ETS, and provides a real-time dashboard for configuring access rules. The plug enforces these rules before authentication, making it perfect for rate limiting, IP filtering, and advanced access control.

## Why RouteShield Stands Out

### 🚀 **All-in-One Solution**
Unlike other packages that focus on a single feature (rate limiting OR IP filtering), RouteShield provides a **complete security suite** in one package. You get route discovery, rate limiting, IP filtering, concurrent limits, time restrictions, and custom responses - all integrated seamlessly.

### 🎯 **Zero-Configuration Route Discovery**
RouteShield automatically discovers all your routes at **compile-time** - no manual route registration needed. It intelligently filters out static assets and Phoenix internal routes, giving you a clean view of your actual application routes.

### ⚡ **Lightning-Fast Performance**
Built on **ETS (Erlang Term Storage)** for in-memory lookups, RouteShield adds minimal overhead to your request pipeline. Rules are cached in ETS with PostgreSQL persistence, giving you the best of both worlds: speed and durability.

### 🎨 **Beautiful LiveView Dashboard**
Unlike command-line tools or configuration files, RouteShield provides a **real-time, interactive dashboard** built with Phoenix LiveView and Tailwind CSS. Manage all your security rules through an intuitive web interface - no code changes required.

### 🔒 **Pre-Authentication Protection**
RouteShield runs **before authentication** in your plug pipeline, protecting your routes from malicious traffic before it reaches your controllers. This is crucial for preventing DDoS attacks, brute force attempts, and unauthorized access.

### 🛠️ **Developer-Friendly**
- **Mix tasks** for easy setup and route discovery
- **Comprehensive documentation** and examples
- **Type-safe** with Ecto schemas
- **Test-friendly** with clear separation of concerns
- **Production-ready** with proper error handling and logging

### 📊 **Enterprise-Grade Features**
- **CIDR notation support** for IP filtering
- **Token bucket algorithm** for accurate rate limiting
- **Global and per-route** rule configurations
- **Custom response messages** with multiple content types
- **Time-based restrictions** with day-of-week support
- **Concurrent connection limits** to prevent resource exhaustion

### 🔄 **Real-Time Updates**
Changes made in the dashboard are immediately reflected in ETS cache - no application restart required. Your security rules take effect instantly.

### 🎁 **Open Source & Extensible**
RouteShield is open source with a clean, modular architecture. Easy to extend with custom rules or integrate with your existing security infrastructure.

## Implemented Features Summary

✅ **Route Discovery** - Automatic compile-time route discovery with ETS storage  
✅ **Rate Limiting** - Per-IP token bucket algorithm with configurable windows  
✅ **IP Filtering** - Per-route whitelist/blacklist + global blacklist with CIDR support  
✅ **Concurrent Limits** - Maximum simultaneous connections per IP  
✅ **Time Restrictions** - Time windows and day-of-week restrictions  
✅ **Custom Responses** - Customizable HTTP status codes and error messages  
✅ **LiveView Dashboard** - Beautiful Tailwind CSS interface for rule management  
✅ **Mix Tasks** - Route discovery and migration generation utilities  
✅ **High Performance** - ETS-based caching with PostgreSQL persistence

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

### Implemented Features

#### 1. Route Discovery
- ✅ Automatic compile-time route discovery
- ✅ ETS storage for fast route lookups
- ✅ Support for dynamic routes (`/users/:id`)
- ✅ Display all routes in dashboard
- ✅ Automatic filtering of static assets and Phoenix internal routes
- ✅ Mix task for manual route discovery: `mix route_shield.discover`

#### 2. Rate Limiting
- ✅ Per-IP rate limiting
- ✅ Configurable requests per time window (e.g., 5 requests per second)
- ✅ Token bucket algorithm
- ✅ ETS-based counter storage with automatic cleanup
- ✅ Customizable rate limit per route
- ✅ Configurable time windows (seconds, minutes, hours)

#### 3. IP Filtering (Whitelist & Blacklist)
- ✅ Per-route IP whitelisting
- ✅ Per-route IP blacklisting
- ✅ Global IP blacklist (applies to all routes)
- ✅ Support for CIDR notation (e.g., `192.168.1.0/24`)
- ✅ Multiple IPs per route
- ✅ Real-time enable/disable
- ✅ Description field for IP entries
- ✅ Expiration support for global blacklist entries

#### 4. Dashboard
- ✅ Beautiful Tailwind CSS interface
- ✅ Real-time route listing
- ✅ Rule configuration UI
- ✅ Live updates (no page refresh needed)
- ✅ User-configurable dashboard route
- ✅ Create, view, and delete rules
- ✅ Manage all rule types from the dashboard

#### 5. Concurrent Request Limits
- ✅ Maximum simultaneous connections per IP
- ✅ Per-route configuration
- ✅ Prevents connection exhaustion attacks
- ✅ ETS-based tracking for real-time enforcement

#### 6. Custom Blocked Responses
- ✅ Customizable HTTP status codes (400, 401, 403, 404, 429, 503)
- ✅ Custom error messages
- ✅ Multiple response formats: JSON, HTML, Plain Text, XML
- ✅ Per-route response configuration
- ✅ Automatic JSON formatting when needed

#### 7. Time-Based Restrictions
- ✅ Time window restrictions (e.g., only 9 AM–5 PM)
- ✅ Day-of-week restrictions (e.g., block weekends)
- ✅ Support for time ranges that wrap midnight
- ✅ Per-route configuration
- ✅ Multiple restrictions per rule

#### 8. Storage & Caching
- ✅ ETS for hot path (route matching, rule lookup)
- ✅ PostgreSQL for persistent storage
- ✅ Automatic cache refresh on rule changes
- ✅ Background cache refresh support
- ✅ Efficient route pattern matching

### Future Features

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
  - `route_shield_ip_filters` - IP whitelist/blacklist entries (per-route)
  - `route_shield_global_ip_blacklist` - Global IP blacklist entries
  - `route_shield_time_restrictions` - Time-based rules
  - `route_shield_concurrent_limits` - Concurrent request limit configurations
  - `route_shield_custom_responses` - Custom blocked response configurations

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

### 2. Install Migrations

```bash
mix route_shield.install
mix ecto.migrate
```

The `mix route_shield.install` command generates a migration file in your
project's `priv/repo/migrations/` directory with all RouteShield tables.

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

### Discover Routes

Routes can be discovered automatically at compile-time or manually via mix task:

```bash
# Manual route discovery
mix route_shield.discover YourApp.Router
```

Or programmatically:

```elixir
# In your application startup
RouteShield.discover_routes(YourApp.Router, YourApp.Repo)
```

### Dashboard

Navigate to `/route_shield` (or your configured path) to:
- View all discovered routes
- Create and manage rules for routes
- Configure rate limits per route
- Manage IP whitelists/blacklists (per-route)
- Manage global IP blacklist
- Set time-based restrictions
- Configure concurrent request limits
- Set custom blocked responses
- Real-time rule updates without page refresh

### Programmatic Usage

```elixir
# Discover routes
RouteShield.discover_routes(YourApp.Router, YourApp.Repo)

# Refresh cache after rule changes (usually automatic via dashboard)
RouteShield.refresh_cache(YourApp.Repo)
```

## Project Structure

```
route_shield/
├── lib/
│   ├── route_shield/
│   │   ├── plug.ex                  # Main plug for enforcement
│   │   ├── router.ex                # Compile-time route discovery
│   │   ├── route_discovery.ex       # Route discovery logic
│   │   ├── dashboard_live.ex        # LiveView dashboard
│   │   ├── application.ex           # Application startup
│   │   ├── rules/
│   │   │   ├── rate_limit.ex        # Rate limiting logic
│   │   │   ├── ip_filter.ex         # IP whitelist/blacklist
│   │   │   ├── time_restriction.ex  # Time-based restrictions
│   │   │   └── concurrent_limit.ex  # Concurrent request limits
│   │   ├── storage/
│   │   │   ├── ets.ex               # ETS operations
│   │   │   └── cache.ex             # Cache refresh logic
│   │   ├── schema/
│   │   │   ├── route.ex
│   │   │   ├── rule.ex
│   │   │   ├── rate_limit.ex
│   │   │   ├── ip_filter.ex
│   │   │   ├── global_ip_blacklist.ex
│   │   │   ├── time_restriction.ex
│   │   │   ├── concurrent_limit.ex
│   │   │   └── custom_response.ex
│   │   └── mix/
│   │       └── tasks/
│   │           ├── route_shield.install.ex    # Migration generator
│   │           └── route_shield.discover.ex   # Route discovery task
│   └── route_shield.ex
├── priv/
│   └── repo/
│       └── migrations/              # Ecto migrations
└── mix.exs
```

## License

MIT
