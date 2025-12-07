ExUnit.start()

# Start ETS tables for tests (only if they don't exist)
try do
  RouteShield.Storage.ETS.start_link()
rescue
  ArgumentError -> :ok  # Tables already exist
end

try do
  RouteShield.Rules.RateLimit.init()
rescue
  ArgumentError -> :ok  # Table already exists
end
