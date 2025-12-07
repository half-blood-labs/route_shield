defmodule RouteShield.Rules.RateLimitTest do
  use ExUnit.Case

  alias RouteShield.Rules.RateLimit

  setup do
    # Clean up buckets before each test by deleting the table and recreating it
    table = :route_shield_rate_limit_buckets

    try do
      :ets.delete(table)
    rescue
      ArgumentError -> :ok
    end

    RateLimit.init()
    :ok
  end

  describe "check_rate_limit/3" do
    test "allows first request" do
      ip = "192.168.1.100"
      rule_id = 1
      config = %{requests_per_window: 10, window_seconds: 60}

      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip, rule_id, config)
    end

    test "allows requests up to the limit" do
      ip = "192.168.1.100"
      rule_id = 1
      config = %{requests_per_window: 5, window_seconds: 60}

      # Make 5 requests, all should be allowed
      for _ <- 1..5 do
        assert {:ok, :allowed} = RateLimit.check_rate_limit(ip, rule_id, config)
      end
    end

    test "blocks request when limit is exceeded" do
      ip = "192.168.1.100"
      rule_id = 1
      config = %{requests_per_window: 3, window_seconds: 60}

      # Make 3 requests (up to limit)
      for _ <- 1..3 do
        assert {:ok, :allowed} = RateLimit.check_rate_limit(ip, rule_id, config)
      end

      # 4th request should be blocked
      assert {:error, :rate_limit_exceeded} =
               RateLimit.check_rate_limit(ip, rule_id, config)
    end

    test "tracks rate limits per IP address" do
      ip1 = "192.168.1.100"
      ip2 = "192.168.1.200"
      rule_id = 1
      config = %{requests_per_window: 2, window_seconds: 60}

      # Exhaust limit for IP1
      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip1, rule_id, config)
      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip1, rule_id, config)

      assert {:error, :rate_limit_exceeded} =
               RateLimit.check_rate_limit(ip1, rule_id, config)

      # IP2 should still have full limit
      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip2, rule_id, config)
      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip2, rule_id, config)

      assert {:error, :rate_limit_exceeded} =
               RateLimit.check_rate_limit(ip2, rule_id, config)
    end

    test "tracks rate limits per rule" do
      ip = "192.168.1.100"
      rule_id1 = 1
      rule_id2 = 2
      config = %{requests_per_window: 2, window_seconds: 60}

      # Exhaust limit for rule1
      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip, rule_id1, config)
      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip, rule_id1, config)

      assert {:error, :rate_limit_exceeded} =
               RateLimit.check_rate_limit(ip, rule_id1, config)

      # Rule2 should still have full limit
      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip, rule_id2, config)
      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip, rule_id2, config)

      assert {:error, :rate_limit_exceeded} =
               RateLimit.check_rate_limit(ip, rule_id2, config)
    end

    test "refills tokens after window expires" do
      ip = "192.168.1.100"
      rule_id = 1
      config = %{requests_per_window: 2, window_seconds: 1}

      # Exhaust limit
      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip, rule_id, config)
      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip, rule_id, config)

      assert {:error, :rate_limit_exceeded} =
               RateLimit.check_rate_limit(ip, rule_id, config)

      # Wait for window to expire
      Process.sleep(1100)

      # Should be allowed again
      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip, rule_id, config)
    end

    test "handles very small window sizes" do
      ip = "192.168.1.100"
      rule_id = 1
      config = %{requests_per_window: 1, window_seconds: 1}

      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip, rule_id, config)

      assert {:error, :rate_limit_exceeded} =
               RateLimit.check_rate_limit(ip, rule_id, config)

      Process.sleep(1100)

      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip, rule_id, config)
    end

    test "handles large request limits" do
      ip = "192.168.1.100"
      rule_id = 1
      config = %{requests_per_window: 1000, window_seconds: 60}

      # Make many requests
      for _ <- 1..100 do
        assert {:ok, :allowed} = RateLimit.check_rate_limit(ip, rule_id, config)
      end

      # Should still have tokens left
      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip, rule_id, config)
    end
  end

  describe "cleanup_old_buckets/2" do
    test "removes old buckets for a specific rule" do
      ip = "192.168.1.100"
      rule_id = 1
      config = %{requests_per_window: 10, window_seconds: 1}

      RateLimit.check_rate_limit(ip, rule_id, config)

      # Wait for window to expire
      Process.sleep(1100)

      # Cleanup should remove old buckets
      RateLimit.cleanup_old_buckets(rule_id, 1)

      # Should be able to create a new bucket
      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip, rule_id, config)
    end
  end

  describe "cleanup_all_old_buckets/1" do
    test "removes all old buckets" do
      ip = "192.168.1.100"
      rule_id1 = 1
      rule_id2 = 2
      config = %{requests_per_window: 10, window_seconds: 1}

      RateLimit.check_rate_limit(ip, rule_id1, config)
      RateLimit.check_rate_limit(ip, rule_id2, config)

      # Wait for window to expire
      Process.sleep(1100)

      # Cleanup should remove all old buckets
      RateLimit.cleanup_all_old_buckets(1)

      # Should be able to create new buckets
      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip, rule_id1, config)
      assert {:ok, :allowed} = RateLimit.check_rate_limit(ip, rule_id2, config)
    end
  end
end
