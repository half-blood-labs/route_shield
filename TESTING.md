# Testing Guide for RouteShield

This guide explains how to run and understand the test suite for RouteShield.

## Prerequisites

Before running tests, make sure you have all dependencies installed:

```bash
mix deps.get
```

## Running Tests

### Run All Tests

```bash
mix test
```

### Run Tests with Coverage

```bash
mix test --cover
```

### Run Specific Test File

```bash
mix test test/route_shield/plug_test.exs
```

### Run Specific Test

```bash
mix test test/route_shield/plug_test.exs:42
```

### Run Tests in Watch Mode

```bash
mix test.watch
```

## Test Structure

The test suite is organized to mirror the application structure:

```
test/
├── test_helper.exs                    # Test setup and configuration
├── route_shield_test.exs              # Main module tests
└── route_shield/
    ├── plug_test.exs                  # Plug integration tests
    ├── route_discovery_test.exs       # Route discovery tests
    └── rules/
        ├── rate_limit_test.exs        # Rate limiting tests
        └── ip_filter_test.exs         # IP filtering tests
    └── storage/
        ├── ets_test.exs               # ETS storage tests
        └── cache_test.exs             # Cache refresh tests
```

## Test Coverage

### RouteShield.Plug Tests

Tests cover:
- Route matching (exact and parameterized paths)
- IP extraction from headers (x-forwarded-for, x-real-ip, remote_ip)
- Rule enforcement (IP filtering, rate limiting)
- Priority-based rule application
- Disabled rule handling
- Error responses (403, 429)

### RouteShield.Rules.RateLimit Tests

Tests cover:
- Token bucket algorithm
- Per-IP rate limiting
- Per-rule rate limiting
- Window expiration and token refill
- Edge cases (small windows, large limits)
- Bucket cleanup

### RouteShield.Rules.IpFilter Tests

Tests cover:
- Whitelist and blacklist functionality
- CIDR notation support (/0, /8, /24, /32)
- Multiple filter handling
- Precedence (blacklist over whitelist)
- Disabled filter handling
- Invalid IP/CIDR handling

### RouteShield.RouteDiscovery Tests

Tests cover:
- Route discovery from router modules
- Custom `__route_shield_routes__/0` function support
- Route storage in ETS and database
- Route updates for existing routes
- Error handling

### RouteShield.Storage.ETS Tests

Tests cover:
- Route storage and retrieval
- Rule storage and retrieval
- Rate limit storage and retrieval
- IP filter storage and retrieval
- Time restriction storage and retrieval
- Filtering by enabled status
- Priority sorting
- Table clearing operations

### RouteShield.Storage.Cache Tests

Tests cover:
- Full cache refresh
- Individual component refresh (rules, rate limits, etc.)
- Rule-specific refresh
- Cache clearing before refresh

## Test Setup

The test suite uses ETS tables for in-memory storage, which are:
- Initialized in `test_helper.exs`
- Cleared before each test via `setup` blocks
- Isolated per test to prevent interference

## Mocking

The tests use simple struct-based mocks for the repository instead of heavy mocking libraries. This keeps tests:
- Fast
- Simple
- Easy to understand
- Independent of external dependencies

## Continuous Integration

For CI/CD pipelines, run:

```bash
mix test --cover
```

This will:
1. Run all tests
2. Generate coverage reports
3. Exit with appropriate status codes

## Writing New Tests

When adding new functionality:

1. **Add tests in the appropriate file** matching the module structure
2. **Use descriptive test names** that explain what is being tested
3. **Clean up ETS tables** in `setup` blocks
4. **Test both success and failure cases**
5. **Test edge cases** (empty lists, nil values, boundary conditions)

Example:

```elixir
defmodule RouteShield.NewFeatureTest do
  use ExUnit.Case

  setup do
    # Clean up before each test
    RouteShield.Storage.ETS.clear_all()
    :ok
  end

  describe "new_functionality/1" do
    test "handles success case" do
      # Test implementation
    end

    test "handles error case" do
      # Test implementation
    end
  end
end
```

## Troubleshooting

### Tests Fail with ETS Table Errors

If you see errors about ETS tables not existing:
- Make sure `test_helper.exs` is properly loading
- Check that `RouteShield.Storage.ETS.start_link()` is called

### Tests Interfere with Each Other

If tests are affecting each other:
- Ensure each test has a `setup` block that clears ETS tables
- Check that test data uses unique IDs

### Rate Limit Tests Timing Out

Rate limit tests use `Process.sleep/1` for window expiration:
- These tests may be slower
- Consider using `@tag :slow` for such tests
- Run them separately if needed: `mix test --exclude slow`

## Performance

The test suite is designed to be fast:
- Uses in-memory ETS tables (no database required)
- Minimal mocking overhead
- Parallel test execution (ExUnit default)

Typical test run time: < 5 seconds for the full suite.

