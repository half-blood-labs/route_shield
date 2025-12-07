defmodule RouteShield.Rules.IpFilterTest do
  use ExUnit.Case

  alias RouteShield.Rules.IpFilter
  alias RouteShield.Storage.ETS
  alias RouteShield.Schema.IpFilter, as: IpFilterSchema

  setup do
    ETS.clear_ip_filters()
    :ok
  end

  describe "check_ip_access/2" do
    test "allows access when no filters exist" do
      assert {:ok, :allowed} = IpFilter.check_ip_access("192.168.1.100", 1)
    end

    test "blocks IP when it's in blacklist" do
      rule_id = 1
      ip_filter = %IpFilterSchema{
        id: 1,
        rule_id: rule_id,
        ip_address: "192.168.1.100",
        type: :blacklist,
        enabled: true
      }

      ETS.store_ip_filter(ip_filter)

      assert {:error, :ip_blacklisted} =
               IpFilter.check_ip_access("192.168.1.100", rule_id)
    end

    test "allows IP when it's not in blacklist" do
      rule_id = 1
      ip_filter = %IpFilterSchema{
        id: 1,
        rule_id: rule_id,
        ip_address: "192.168.1.100",
        type: :blacklist,
        enabled: true
      }

      ETS.store_ip_filter(ip_filter)

      assert {:ok, :allowed} = IpFilter.check_ip_access("192.168.1.200", rule_id)
    end

    test "allows IP when it's in whitelist" do
      rule_id = 1
      ip_filter = %IpFilterSchema{
        id: 1,
        rule_id: rule_id,
        ip_address: "192.168.1.100",
        type: :whitelist,
        enabled: true
      }

      ETS.store_ip_filter(ip_filter)

      assert {:ok, :allowed} = IpFilter.check_ip_access("192.168.1.100", rule_id)
    end

    test "blocks IP when it's not in whitelist but whitelist exists" do
      rule_id = 1
      ip_filter = %IpFilterSchema{
        id: 1,
        rule_id: rule_id,
        ip_address: "192.168.1.100",
        type: :whitelist,
        enabled: true
      }

      ETS.store_ip_filter(ip_filter)

      assert {:error, :ip_not_whitelisted} =
               IpFilter.check_ip_access("192.168.1.200", rule_id)
    end

    test "blacklist takes precedence over whitelist" do
      rule_id = 1
      blacklist_filter = %IpFilterSchema{
        id: 1,
        rule_id: rule_id,
        ip_address: "192.168.1.100",
        type: :blacklist,
        enabled: true
      }

      whitelist_filter = %IpFilterSchema{
        id: 2,
        rule_id: rule_id,
        ip_address: "192.168.1.100",
        type: :whitelist,
        enabled: true
      }

      ETS.store_ip_filter(blacklist_filter)
      ETS.store_ip_filter(whitelist_filter)

      # Should be blocked even though it's also whitelisted
      assert {:error, :ip_blacklisted} =
               IpFilter.check_ip_access("192.168.1.100", rule_id)
    end

    test "supports CIDR notation for blacklist" do
      rule_id = 1
      ip_filter = %IpFilterSchema{
        id: 1,
        rule_id: rule_id,
        ip_address: "192.168.1.0/24",
        type: :blacklist,
        enabled: true
      }

      ETS.store_ip_filter(ip_filter)

      # IPs in the CIDR range should be blocked
      assert {:error, :ip_blacklisted} =
               IpFilter.check_ip_access("192.168.1.100", rule_id)

      assert {:error, :ip_blacklisted} =
               IpFilter.check_ip_access("192.168.1.1", rule_id)

      assert {:error, :ip_blacklisted} =
               IpFilter.check_ip_access("192.168.1.255", rule_id)

      # IPs outside the range should be allowed
      assert {:ok, :allowed} = IpFilter.check_ip_access("192.168.2.100", rule_id)
    end

    test "supports CIDR notation for whitelist" do
      rule_id = 1
      ip_filter = %IpFilterSchema{
        id: 1,
        rule_id: rule_id,
        ip_address: "10.0.0.0/8",
        type: :whitelist,
        enabled: true
      }

      ETS.store_ip_filter(ip_filter)

      # IPs in the CIDR range should be allowed
      assert {:ok, :allowed} = IpFilter.check_ip_access("10.0.0.1", rule_id)
      assert {:ok, :allowed} = IpFilter.check_ip_access("10.255.255.255", rule_id)

      # IPs outside the range should be blocked
      assert {:error, :ip_not_whitelisted} =
               IpFilter.check_ip_access("192.168.1.100", rule_id)
    end

    test "handles multiple CIDR ranges" do
      rule_id = 1
      filter1 = %IpFilterSchema{
        id: 1,
        rule_id: rule_id,
        ip_address: "192.168.1.0/24",
        type: :blacklist,
        enabled: true
      }

      filter2 = %IpFilterSchema{
        id: 2,
        rule_id: rule_id,
        ip_address: "10.0.0.0/8",
        type: :blacklist,
        enabled: true
      }

      ETS.store_ip_filter(filter1)
      ETS.store_ip_filter(filter2)

      assert {:error, :ip_blacklisted} =
               IpFilter.check_ip_access("192.168.1.100", rule_id)

      assert {:error, :ip_blacklisted} =
               IpFilter.check_ip_access("10.0.0.1", rule_id)

      assert {:ok, :allowed} = IpFilter.check_ip_access("172.16.0.1", rule_id)
    end

    test "ignores disabled filters" do
      rule_id = 1
      ip_filter = %IpFilterSchema{
        id: 1,
        rule_id: rule_id,
        ip_address: "192.168.1.100",
        type: :blacklist,
        enabled: false
      }

      ETS.store_ip_filter(ip_filter)

      # Should be allowed because filter is disabled
      assert {:ok, :allowed} = IpFilter.check_ip_access("192.168.1.100", rule_id)
    end

    test "handles invalid IP addresses gracefully" do
      rule_id = 1
      ip_filter = %IpFilterSchema{
        id: 1,
        rule_id: rule_id,
        ip_address: "invalid-ip",
        type: :blacklist,
        enabled: true
      }

      ETS.store_ip_filter(ip_filter)

      # Should not crash, but may not match
      result = IpFilter.check_ip_access("192.168.1.100", rule_id)
      assert result in [{:ok, :allowed}, {:error, :ip_blacklisted}]
    end

    test "handles invalid CIDR notation gracefully" do
      rule_id = 1
      ip_filter = %IpFilterSchema{
        id: 1,
        rule_id: rule_id,
        ip_address: "192.168.1.0/invalid",
        type: :blacklist,
        enabled: true
      }

      ETS.store_ip_filter(ip_filter)

      # Should not crash
      assert {:ok, :allowed} = IpFilter.check_ip_access("192.168.1.100", rule_id)
    end

    test "handles /32 CIDR (single IP)" do
      rule_id = 1
      ip_filter = %IpFilterSchema{
        id: 1,
        rule_id: rule_id,
        ip_address: "192.168.1.100/32",
        type: :blacklist,
        enabled: true
      }

      ETS.store_ip_filter(ip_filter)

      assert {:error, :ip_blacklisted} =
               IpFilter.check_ip_access("192.168.1.100", rule_id)

      assert {:ok, :allowed} = IpFilter.check_ip_access("192.168.1.101", rule_id)
    end

    test "handles /0 CIDR (all IPs)" do
      rule_id = 1
      ip_filter = %IpFilterSchema{
        id: 1,
        rule_id: rule_id,
        ip_address: "0.0.0.0/0",
        type: :blacklist,
        enabled: true
      }

      ETS.store_ip_filter(ip_filter)

      # All IPs should match
      assert {:error, :ip_blacklisted} =
               IpFilter.check_ip_access("192.168.1.100", rule_id)

      assert {:error, :ip_blacklisted} =
               IpFilter.check_ip_access("10.0.0.1", rule_id)

      assert {:error, :ip_blacklisted} =
               IpFilter.check_ip_access("172.16.0.1", rule_id)
    end
  end
end
