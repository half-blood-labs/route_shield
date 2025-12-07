defmodule RouteShield.Plug do
  @moduledoc """
  Main plug for route protection and rule enforcement.
  Should be placed before authentication in the pipeline.
  """

  import Plug.Conn
  alias RouteShield.Storage.ETS
  alias RouteShield.Rules.{RateLimit, IpFilter}

  def init(opts), do: opts

  def call(conn, _opts) do
    method = conn.method
    path = conn.request_path

    case find_matching_route(method, path, conn) do
      {:ok, route} ->
        conn = assign(conn, :route_shield_route, route)

        route_id = Map.get(route, :id)

        if route_id do
          rules = ETS.get_rules_for_route(route_id)

          case apply_rules(conn, rules) do
            {:ok, :allowed} -> conn
            {:error, reason} -> block_request(conn, reason)
          end
        else
          conn
        end

      {:error, :not_found} ->
        conn
    end
  end

  defp find_matching_route(method, path, conn) do
    case ETS.get_route(method, path) do
      {:ok, route} -> {:ok, route}
      {:error, :not_found} -> find_route_by_matching(method, path, conn)
    end
  end

  defp find_route_by_matching(method, path, _conn) do
    all_routes = ETS.list_routes()

    matching_route =
      Enum.find(all_routes, fn route ->
        route.method == method && path_matches?(route.path_pattern, path)
      end)

    if matching_route do
      {:ok, matching_route}
    else
      {:error, :not_found}
    end
  end

  defp path_matches?(pattern, path) do
    pattern_regex =
      pattern
      |> String.replace(~r/:(\w+)/, "[^/]+")
      |> Regex.compile!()

    Regex.match?(pattern_regex, path)
  end

  defp apply_rules(_conn, rules) when length(rules) == 0 do
    {:ok, :allowed}
  end

  defp apply_rules(conn, rules) do
    ip_address = get_client_ip(conn)

    Enum.reduce_while(rules, {:ok, :allowed}, fn rule, _acc ->
      case check_rule(conn, rule, ip_address) do
        {:ok, :allowed} -> {:cont, {:ok, :allowed}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp check_rule(conn, rule, ip_address) do
    case IpFilter.check_ip_access(ip_address, rule.id) do
      {:error, reason} -> {:error, reason}
      {:ok, :allowed} -> check_rate_limit(conn, rule, ip_address)
    end
  end

  defp check_rate_limit(_conn, rule, ip_address) do
    case ETS.get_rate_limit_for_rule(rule.id) do
      {:ok, rate_limit_config} ->
        RateLimit.check_rate_limit(ip_address, rule.id, rate_limit_config)

      {:error, :not_found} ->
        {:ok, :allowed}
    end
  end

  defp get_client_ip(conn) do
    conn
    |> get_req_header("x-forwarded-for")
    |> List.first()
    |> case do
      nil ->
        conn
        |> get_req_header("x-real-ip")
        |> List.first()
        |> case do
          nil -> to_string(:inet.ntoa(conn.remote_ip))
          ip -> String.split(ip, ",") |> List.first() |> String.trim()
        end

      ip ->
        String.split(ip, ",") |> List.first() |> String.trim()
    end
  end

  defp block_request(conn, reason) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status_code_for_reason(reason), error_message(reason))
    |> halt()
  end

  defp status_code_for_reason(:rate_limit_exceeded), do: 429
  defp status_code_for_reason(:ip_blacklisted), do: 403
  defp status_code_for_reason(:ip_not_whitelisted), do: 403
  defp status_code_for_reason(_), do: 403

  defp error_message(:rate_limit_exceeded) do
    Jason.encode!(%{error: "Rate limit exceeded"})
  end

  defp error_message(:ip_blacklisted) do
    Jason.encode!(%{error: "IP address is blacklisted"})
  end

  defp error_message(:ip_not_whitelisted) do
    Jason.encode!(%{error: "IP address is not whitelisted"})
  end

  defp error_message(_) do
    Jason.encode!(%{error: "Access denied"})
  end
end
