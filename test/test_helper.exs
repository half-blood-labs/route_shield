ExUnit.start()

# Start ETS tables for tests (only if they don't exist)
try do
  RouteShield.Storage.ETS.start_link()
rescue
  # Tables already exist
  ArgumentError -> :ok
end

try do
  RouteShield.Rules.RateLimit.init()
rescue
  # Table already exists
  ArgumentError -> :ok
end
