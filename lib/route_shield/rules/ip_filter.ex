defmodule RouteShield.Rules.IpFilter do
  @moduledoc """
  IP whitelist/blacklist filtering with CIDR notation support.
  """

  alias RouteShield.Storage.ETS

  def check_ip_access(ip_address, rule_id) do
    ip_filters = ETS.get_ip_filters_for_rule(rule_id)

    if Enum.empty?(ip_filters) do
      {:ok, :allowed}
    else
      whitelist_filters = Enum.filter(ip_filters, &(&1.type == :whitelist))
      blacklist_filters = Enum.filter(ip_filters, &(&1.type == :blacklist))

      # Check blacklist first
      if Enum.any?(blacklist_filters, &ip_matches?(&1.ip_address, ip_address)) do
        {:error, :ip_blacklisted}
      else
        # If whitelist exists, IP must be in whitelist
        if Enum.empty?(whitelist_filters) do
          {:ok, :allowed}
        else
          if Enum.any?(whitelist_filters, &ip_matches?(&1.ip_address, ip_address)) do
            {:ok, :allowed}
          else
            {:error, :ip_not_whitelisted}
          end
        end
      end
    end
  end

  defp ip_matches?(filter_ip, request_ip) do
    cond do
      # CIDR notation
      String.contains?(filter_ip, "/") ->
        matches_cidr?(filter_ip, request_ip)

      # Exact match
      filter_ip == request_ip ->
        true

      # No match
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
end
