defmodule Mix.Tasks.RouteShield.Install do
  @moduledoc """
  Installs RouteShield by generating a migration file.

  This task creates a migration file in your project's priv/repo/migrations
  directory that sets up all RouteShield tables.

  The migration is idempotent - you can re-run `mix route_shield.install` and
  `mix ecto.migrate` to add any missing tables when new features are added.

  ## Examples

      mix route_shield.install

  The generated migration file will be named with a timestamp, for example:
      YYYYMMDDHHMMSS_install_route_shield.exs
  """
  use Mix.Task

  @shortdoc "Generates a migration to install RouteShield"

  @migration_template """
  defmodule __REPO_MODULE__.Migrations.InstallRouteShield do
    use Ecto.Migration

    def up do
      # Helper function to create table only if it doesn't exist
      create_table_if_not_exists = fn table_name, columns_sql ->
        execute("CREATE TABLE IF NOT EXISTS " <> table_name <> " (" <> columns_sql <> ")")
      end

      # Create routes table (idempotent)
      create_table_if_not_exists.("route_shield_routes",
        "id BIGSERIAL PRIMARY KEY, " <>
        "method VARCHAR(255) NOT NULL, " <>
        "path_pattern VARCHAR(255) NOT NULL, " <>
        "controller VARCHAR(255), " <>
        "action VARCHAR(255), " <>
        "helper VARCHAR(255), " <>
        "discovered_at TIMESTAMP, " <>
        "inserted_at TIMESTAMP NOT NULL, " <>
        "updated_at TIMESTAMP NOT NULL")

      create_if_not_exists index(:route_shield_routes, [:method, :path_pattern], unique: true)
      create_if_not_exists index(:route_shield_routes, [:controller, :action])

      # Create rules table (idempotent)
      create_table_if_not_exists.("route_shield_rules",
        "id BIGSERIAL PRIMARY KEY, " <>
        "route_id BIGINT NOT NULL REFERENCES route_shield_routes(id) ON DELETE CASCADE, " <>
        "enabled BOOLEAN NOT NULL DEFAULT true, " <>
        "priority INTEGER NOT NULL DEFAULT 0, " <>
        "description VARCHAR(255), " <>
        "inserted_at TIMESTAMP NOT NULL, " <>
        "updated_at TIMESTAMP NOT NULL")

      create_if_not_exists index(:route_shield_rules, [:route_id])
      create_if_not_exists index(:route_shield_rules, [:enabled])

      # Create rate limits table (idempotent)
      create_table_if_not_exists.("route_shield_rate_limits",
        "id BIGSERIAL PRIMARY KEY, " <>
        "rule_id BIGINT NOT NULL REFERENCES route_shield_rules(id) ON DELETE CASCADE, " <>
        "requests_per_window INTEGER NOT NULL, " <>
        "window_seconds INTEGER NOT NULL, " <>
        "enabled BOOLEAN NOT NULL DEFAULT true, " <>
        "inserted_at TIMESTAMP NOT NULL, " <>
        "updated_at TIMESTAMP NOT NULL")

      create_if_not_exists index(:route_shield_rate_limits, [:rule_id])
      create_if_not_exists index(:route_shield_rate_limits, [:enabled])

      # Create IP filters table (idempotent)
      create_table_if_not_exists.("route_shield_ip_filters",
        "id BIGSERIAL PRIMARY KEY, " <>
        "rule_id BIGINT NOT NULL REFERENCES route_shield_rules(id) ON DELETE CASCADE, " <>
        "ip_address VARCHAR(255) NOT NULL, " <>
        "type VARCHAR(255) NOT NULL, " <>
        "enabled BOOLEAN NOT NULL DEFAULT true, " <>
        "description VARCHAR(255), " <>
        "inserted_at TIMESTAMP NOT NULL, " <>
        "updated_at TIMESTAMP NOT NULL")

      create_if_not_exists index(:route_shield_ip_filters, [:rule_id])
      create_if_not_exists index(:route_shield_ip_filters, [:type, :enabled])
      create_if_not_exists index(:route_shield_ip_filters, [:ip_address])

      # Create time restrictions table (idempotent)
      create_table_if_not_exists.("route_shield_time_restrictions",
        "id BIGSERIAL PRIMARY KEY, " <>
        "rule_id BIGINT NOT NULL REFERENCES route_shield_rules(id) ON DELETE CASCADE, " <>
        "start_time TIME, " <>
        "end_time TIME, " <>
        "days_of_week INTEGER[], " <>
        "timezone VARCHAR(255) NOT NULL DEFAULT 'UTC', " <>
        "enabled BOOLEAN NOT NULL DEFAULT true, " <>
        "inserted_at TIMESTAMP NOT NULL, " <>
        "updated_at TIMESTAMP NOT NULL")

      create_if_not_exists index(:route_shield_time_restrictions, [:rule_id])
      create_if_not_exists index(:route_shield_time_restrictions, [:enabled])

      # Create concurrent limits table (idempotent)
      create_table_if_not_exists.("route_shield_concurrent_limits",
        "id BIGSERIAL PRIMARY KEY, " <>
        "rule_id BIGINT NOT NULL REFERENCES route_shield_rules(id) ON DELETE CASCADE, " <>
        "max_concurrent INTEGER NOT NULL DEFAULT 10, " <>
        "enabled BOOLEAN NOT NULL DEFAULT true, " <>
        "inserted_at TIMESTAMP NOT NULL, " <>
        "updated_at TIMESTAMP NOT NULL, " <>
        "UNIQUE(rule_id)")

      create_if_not_exists index(:route_shield_concurrent_limits, [:rule_id])

      # Create custom responses table (idempotent)
      create_table_if_not_exists.("route_shield_custom_responses",
        "id BIGSERIAL PRIMARY KEY, " <>
        "rule_id BIGINT NOT NULL REFERENCES route_shield_rules(id) ON DELETE CASCADE, " <>
        "status_code INTEGER NOT NULL DEFAULT 403, " <>
        "message TEXT, " <>
        "content_type VARCHAR(255) NOT NULL DEFAULT 'application/json', " <>
        "enabled BOOLEAN NOT NULL DEFAULT true, " <>
        "inserted_at TIMESTAMP NOT NULL, " <>
        "updated_at TIMESTAMP NOT NULL, " <>
        "UNIQUE(rule_id)")

      create_if_not_exists index(:route_shield_custom_responses, [:rule_id])

      # Create global IP blacklist table (idempotent)
      create_table_if_not_exists.("route_shield_global_ip_blacklist",
        "id BIGSERIAL PRIMARY KEY, " <>
        "ip_address VARCHAR(255) NOT NULL, " <>
        "enabled BOOLEAN NOT NULL DEFAULT true, " <>
        "description VARCHAR(255), " <>
        "expires_at TIMESTAMP, " <>
        "inserted_at TIMESTAMP NOT NULL, " <>
        "updated_at TIMESTAMP NOT NULL")

      create_if_not_exists index(:route_shield_global_ip_blacklist, [:ip_address])
      create_if_not_exists index(:route_shield_global_ip_blacklist, [:enabled])
      create_if_not_exists index(:route_shield_global_ip_blacklist, [:expires_at])
    end

    def down do
      drop_if_exists table(:route_shield_global_ip_blacklist)
      drop_if_exists table(:route_shield_custom_responses)
      drop_if_exists table(:route_shield_concurrent_limits)
      drop_if_exists table(:route_shield_time_restrictions)
      drop_if_exists table(:route_shield_ip_filters)
      drop_if_exists table(:route_shield_rate_limits)
      drop_if_exists table(:route_shield_rules)
      drop_if_exists table(:route_shield_routes)
    end
  end
  """

  def run(_args) do
    repo = get_repo()

    if File.exists?("priv/repo/migrations") do
      generate_migration(repo)
    else
      Mix.shell().error("""
      Could not find priv/repo/migrations directory.

      Please run this command from your project root, or create the migrations
      directory first with:
          mkdir -p priv/repo/migrations
      """)
    end
  end

  defp get_repo do
    config = Mix.Project.config()
    app = config[:app]

    case Application.get_env(app, :ecto_repos, []) do
      [repo | _] ->
        repo

      [] ->
        Mix.shell().error("""
        No Ecto repo found. Please configure your repo in config/config.exs:

            config :#{app}, ecto_repos: [YourApp.Repo]
        """)

        Mix.raise("No Ecto repo configured")
    end
  end

  defp generate_migration(repo) do
    repo_module = inspect(repo)
    timestamp = timestamp()
    filename = "#{timestamp}_install_route_shield.exs"
    path = Path.join(["priv", "repo", "migrations", filename])

    if File.exists?(path) do
      Mix.shell().error("Migration file already exists: #{path}")
      Mix.raise("Migration file exists")
    end

    content = String.replace(@migration_template, "__REPO_MODULE__", repo_module)

    File.write!(path, content)

    Mix.shell().info("""
    Generated migration: #{path}

    This migration is idempotent - you can re-run it to add any missing tables
    when RouteShield is updated with new features.

    Now run:
        mix ecto.migrate
    """)
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)
end
