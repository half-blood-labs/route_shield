defmodule RouteShield.Plug do
  @moduledoc """
  Main plug for route protection and rule enforcement.
  Should be placed before authentication in the pipeline.
  """

  import Plug.Conn
  alias RouteShield.Storage.ETS
  alias RouteShield.Rules.{RateLimit, IpFilter, TimeRestriction, ConcurrentLimit}

  def init(opts), do: opts

  def call(conn, _opts) do
    method = conn.method
    path = conn.request_path
    ip_address = get_client_ip(conn)

    # Check global IP blacklist first (applies to all routes)
    if global_ip_blacklisted?(ip_address) do
      block_request(conn, :ip_blacklisted)
    else
      case find_matching_route(method, path, conn) do
        {:ok, route} ->
          conn = assign(conn, :route_shield_route, route)

          route_id = Map.get(route, :id)

          if route_id do
            rules = ETS.get_rules_for_route(route_id)

            case apply_rules(conn, rules, ip_address) do
              {:ok, :allowed} -> conn
              {:error, reason} -> block_request_with_custom_response(conn, reason, route_id)
            end
          else
            conn
          end

        {:error, :not_found} ->
          conn
      end
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

  defp apply_rules(_conn, rules, _ip_address) when length(rules) == 0 do
    {:ok, :allowed}
  end

  defp apply_rules(conn, rules, ip_address) do
    Enum.reduce_while(rules, {:ok, :allowed}, fn rule, _acc ->
      case check_rule(conn, rule, ip_address) do
        {:ok, :allowed} -> {:cont, {:ok, :allowed}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp check_rule(conn, rule, ip_address) do
    case IpFilter.check_ip_access(ip_address, rule.id) do
      {:error, reason} ->
        {:error, reason}

      {:ok, :allowed} ->
        case TimeRestriction.check_time_access(rule.id) do
          {:error, reason} -> {:error, reason}
          {:ok, :allowed} -> check_rate_limit(conn, rule, ip_address)
        end
    end
  end

  defp check_rate_limit(_conn, rule, ip_address) do
    case ETS.get_rate_limit_for_rule(rule.id) do
      {:ok, rate_limit_config} ->
        RateLimit.check_rate_limit(ip_address, rule.id, rate_limit_config)

      {:error, :not_found} ->
        check_concurrent_limit(rule, ip_address)
    end
  end

  defp check_concurrent_limit(rule, ip_address) do
    case ETS.get_concurrent_limit_for_rule(rule.id) do
      {:ok, concurrent_limit} ->
        ConcurrentLimit.check_concurrent_limit(
          ip_address,
          rule.id,
          concurrent_limit.max_concurrent
        )

      {:error, :not_found} ->
        {:ok, :allowed}
    end
  end

  defp global_ip_blacklisted?(ip_address) do
    global_blacklist = ETS.get_global_blacklist_entries()

    Enum.any?(global_blacklist, fn entry ->
      ip_matches?(entry.ip_address, ip_address)
    end)
  end

  defp ip_matches?(filter_ip, request_ip) do
    cond do
      String.contains?(filter_ip, "/") ->
        matches_cidr?(filter_ip, request_ip)

      filter_ip == request_ip ->
        true

      true ->
        false
    end
  end

  defp matches_cidr?(cidr_string, ip_string) do
    case parse_cidr(cidr_string) do
      {:ok, {network, mask}} ->
        case parse_ip(ip_string) do
          {:ok, ip} -> ip_in_cidr?(ip, network, mask)
          _ -> false
        end

      _ ->
        false
    end
  end

  defp parse_cidr(cidr_string) do
    case String.split(cidr_string, "/") do
      [ip_str, mask_str] ->
        case {parse_ip(ip_str), Integer.parse(mask_str)} do
          {{:ok, ip}, {mask, ""}} when mask >= 0 and mask <= 32 ->
            {:ok, {ip, mask}}

          _ ->
            :error
        end

      _ ->
        :error
    end
  end

  defp parse_ip(ip_string) do
    case :inet.parse_address(String.to_charlist(ip_string)) do
      {:ok, ip_tuple} -> {:ok, ip_tuple}
      _ -> :error
    end
  end

  defp ip_in_cidr?(ip, network, mask) do
    import Bitwise
    ip_int = ip_to_int(ip)
    network_int = ip_to_int(network)
    mask_int = bitmask(mask)

    (ip_int &&& mask_int) == (network_int &&& mask_int)
  end

  defp ip_to_int({a, b, c, d}) do
    <<int::32>> = <<a, b, c, d>>
    int
  end

  defp bitmask(bits) do
    <<mask::32>> = <<-1::size(bits), 0::size(32 - bits)>>
    mask
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
    block_request_with_custom_response(conn, reason, nil)
  end

  defp block_request_with_custom_response(conn, reason, route_id) do
    # Check for custom response configuration
    custom_response =
      if route_id do
        case ETS.get_custom_response_for_rule(route_id) do
          {:ok, response} -> response
          _ -> nil
        end
      else
        nil
      end

    if custom_response do
      status_code = custom_response.status_code
      message = custom_response.message || error_message(reason)
      content_type = custom_response.content_type

      conn
      |> put_resp_content_type(content_type)
      |> send_resp(status_code, format_message(message, content_type))
      |> halt()
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(status_code_for_reason(reason), error_message(reason))
      |> halt()
    end
  end

  defp format_message(message, "application/json") do
    case Jason.decode(message) do
      {:ok, _} -> message
      _ -> Jason.encode!(%{error: message})
    end
  end

  defp format_message(message, "text/html") do
    "<!DOCTYPE html><html><head><title>Access Denied</title></head><body><h1>Access Denied</h1><p>#{message}</p></body></html>"
  end

  defp format_message(message, "text/plain") do
    message
  end

  defp format_message(message, _) do
    message
  end

  defp status_code_for_reason(:rate_limit_exceeded), do: 429
  defp status_code_for_reason(:ip_blacklisted), do: 403
  defp status_code_for_reason(:ip_not_whitelisted), do: 403
  defp status_code_for_reason(:time_restricted), do: 403
  defp status_code_for_reason(:concurrent_limit_exceeded), do: 429
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

  defp error_message(:time_restricted) do
    Jason.encode!(%{error: "Access restricted at this time"})
  end

  defp error_message(:concurrent_limit_exceeded) do
    Jason.encode!(%{error: "Too many concurrent requests"})
  end

  defp error_message(_) do
    Jason.encode!(%{error: "Access denied"})
  end
end
