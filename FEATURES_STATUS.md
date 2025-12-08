# RouteShield Features Status

## ✅ Implemented Features (MVP)

### 1. Route Discovery
- ✅ Automatic compile-time route discovery
- ✅ ETS storage for fast route lookups
- ✅ Support for dynamic routes (`/users/:id`)
- ✅ Filter out static assets and internal routes
- ✅ Display all routes in dashboard
- ✅ Auto-load routes from DB on startup
- ✅ Optional auto-discovery on startup

### 2. Rate Limiting
- ✅ Per-IP rate limiting
- ✅ Configurable requests per time window
- ✅ Token bucket algorithm
- ✅ ETS-based counter storage with cleanup
- ✅ Customizable rate limit per route
- ✅ Automatic cleanup of old buckets

### 3. IP Filtering
- ✅ Per-route IP whitelisting
- ✅ Per-route IP blacklisting (actually implemented!)
- ✅ Support for CIDR notation (e.g., `192.168.1.0/24`)
- ✅ Multiple IPs per route
- ✅ Real-time enable/disable
- ✅ Blacklist checked before whitelist

### 4. Dashboard
- ✅ Beautiful self-contained Tailwind CSS interface
- ✅ Real-time route listing
- ✅ Rule configuration UI
- ✅ Create/delete rules
- ✅ Add rate limits per rule
- ✅ Add IP filters (whitelist/blacklist) per rule
- ✅ Live updates (no page refresh needed)
- ✅ User-configurable dashboard route

### 5. Rule Management
- ✅ Rules automatically loaded from DB to ETS on startup
- ✅ Rules are per-route (via route_id)
- ✅ Rule priority support (schema ready)
- ✅ Enable/disable rules
- ✅ Real-time cache refresh when rules change

## ⚠️ Partially Implemented

### 6. Time-Based Restrictions
- ✅ Schema exists (`route_shield_time_restrictions` table)
- ✅ ETS storage functions exist
- ❌ Not enforced in plug yet
- ❌ No dashboard UI yet

## ❌ Not Yet Implemented (Phase 2)

### 7. Concurrent Request Limits
- Maximum simultaneous connections per IP
- Per-route configuration
- Prevents connection exhaustion attacks

### 8. Custom Blocked Responses
- Customizable HTTP status codes (currently hardcoded)
- Custom error messages (currently hardcoded JSON)
- HTML response formats
- Per-route response configuration

### 9. Global IP Blacklist
- Currently only per-route blacklist
- Need global blacklist that applies to all routes

## ❌ Future Features (Phase 3)

### 10. Geographic Restrictions
- Country-based blocking/allowing
- IP geolocation integration
- Per-route configuration

### 11. Request Pattern Matching
- Block suspicious URL patterns
- Regex-based pattern matching
- Custom rule conditions

### 12. Advanced Logging & Analytics
- Request/block logging
- Real-time statistics (requests/sec, blocked count)
- Historical data visualization
- Export capabilities

### 13. Additional Security Features
- User agent blocking (block bots/scrapers)
- API key validation (require custom header)
- Custom header requirements
- Request size limits
- Maintenance mode per route
- Rule priority/ordering (schema ready, not enforced)
- Bypass rules for specific conditions (e.g., internal IPs)

## Rule Enforcement Flow

**Current Implementation:**
1. Request comes in → `RouteShield.Plug.call/2`
2. Finds matching route by `method + path` → gets `route_id`
3. Gets all enabled rules for that `route_id` from ETS
4. For each rule (in priority order):
   - Check IP filter (blacklist → whitelist)
   - If IP passes, check rate limit
   - If any rule fails → block request (403/429)
5. If all rules pass → allow request

**Rules are definitely per-route** - each rule has a `route_id` that links it to a specific route.

