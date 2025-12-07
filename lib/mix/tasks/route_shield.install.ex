defmodule Mix.Tasks.RouteShield.Install do
  @moduledoc """
  Installs RouteShield by generating a migration file.

  This task creates a migration file in your project's priv/repo/migrations
  directory that sets up all RouteShield tables.

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
      # Create routes table
      create table(:route_shield_routes) do
        add :method, :string, null: false
        add :path_pattern, :string, null: false
        add :controller, :string
        add :action, :string
        add :helper, :string
        add :discovered_at, :utc_datetime

        timestamps()
      end

      create index(:route_shield_routes, [:method, :path_pattern], unique: true)
      create index(:route_shield_routes, [:controller, :action])

      # Create rules table
      create table(:route_shield_rules) do
        add :route_id, references(:route_shield_routes, on_delete: :delete_all), null: false
        add :enabled, :boolean, default: true, null: false
        add :priority, :integer, default: 0, null: false
        add :description, :string

        timestamps()
      end

      create index(:route_shield_rules, [:route_id])
      create index(:route_shield_rules, [:enabled])

      # Create rate limits table
      create table(:route_shield_rate_limits) do
        add :rule_id, references(:route_shield_rules, on_delete: :delete_all), null: false
        add :requests_per_window, :integer, null: false
        add :window_seconds, :integer, null: false
        add :enabled, :boolean, default: true, null: false

        timestamps()
      end

      create index(:route_shield_rate_limits, [:rule_id])
      create index(:route_shield_rate_limits, [:enabled])

      # Create IP filters table
      create table(:route_shield_ip_filters) do
        add :rule_id, references(:route_shield_rules, on_delete: :delete_all), null: false
        add :ip_address, :string, null: false
        add :type, :string, null: false  # whitelist or blacklist
        add :enabled, :boolean, default: true, null: false
        add :description, :string

        timestamps()
      end

      create index(:route_shield_ip_filters, [:rule_id])
      create index(:route_shield_ip_filters, [:type, :enabled])
      create index(:route_shield_ip_filters, [:ip_address])

      # Create time restrictions table
      create table(:route_shield_time_restrictions) do
        add :rule_id, references(:route_shield_rules, on_delete: :delete_all), null: false
        add :start_time, :time
        add :end_time, :time
        add :days_of_week, {:array, :integer}
        add :timezone, :string, default: "UTC", null: false
        add :enabled, :boolean, default: true, null: false

        timestamps()
      end

      create index(:route_shield_time_restrictions, [:rule_id])
      create index(:route_shield_time_restrictions, [:enabled])
    end

    def down do
      drop table(:route_shield_time_restrictions)
      drop table(:route_shield_ip_filters)
      drop table(:route_shield_rate_limits)
      drop table(:route_shield_rules)
      drop table(:route_shield_routes)
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
