defmodule RouteShield.DashboardLive do
  @moduledoc """
  Phoenix LiveView dashboard for managing RouteShield rules.
  """

  use Phoenix.LiveView, layout: false
  import Ecto.Query, only: [from: 2]
  alias RouteShield.Storage.ETS
  alias RouteShield.Storage.Cache

  alias RouteShield.Schema.{
    Route,
    Rule,
    RateLimit,
    IpFilter,
    TimeRestriction,
    ConcurrentLimit,
    CustomResponse,
    GlobalIpBlacklist
  }

  def mount(_params, _session, socket) do
    repo = get_repo()

    # Refresh all rules from database into ETS (in case they weren't loaded on startup)
    try do
      Cache.refresh_all(repo)
    rescue
      error ->
        require Logger

        Logger.warning(
          "RouteShield: Could not refresh cache on dashboard mount: #{inspect(error)}"
        )
    end

    routes = repo.all(Route) |> Enum.sort_by(&{&1.method, &1.path_pattern})

    Enum.each(routes, &ETS.store_route/1)

    # Load global blacklist entries
    global_blacklist = repo.all(GlobalIpBlacklist) |> Enum.filter(& &1.enabled)

    socket =
      socket
      |> assign(:routes, routes)
      |> assign(:selected_route, nil)
      |> assign(:rules, [])
      |> assign(:rate_limits, [])
      |> assign(:ip_filters, [])
      |> assign(:time_restrictions, [])
      |> assign(:concurrent_limits, [])
      |> assign(:custom_responses, [])
      |> assign(:global_blacklist, global_blacklist)
      |> assign(:show_global_blacklist, false)
      |> assign(:repo, repo)

    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_event("select_route", %{"route_id" => route_id}, socket) do
    route_id = String.to_integer(route_id)
    route = Enum.find(socket.assigns.routes, &(&1.id == route_id))

    rules = ETS.get_rules_for_route(route_id)

    rate_limits =
      rules
      |> Enum.map(fn rule ->
        case ETS.get_rate_limit_for_rule(rule.id) do
          {:ok, rl} -> rl
          _ -> nil
        end
      end)
      |> Enum.filter(& &1)

    ip_filters =
      rules
      |> Enum.flat_map(fn rule ->
        ETS.get_ip_filters_for_rule(rule.id)
      end)

    time_restrictions =
      rules
      |> Enum.flat_map(fn rule ->
        ETS.get_time_restrictions_for_rule(rule.id)
      end)

    concurrent_limits =
      rules
      |> Enum.map(fn rule ->
        case ETS.get_concurrent_limit_for_rule(rule.id) do
          {:ok, cl} -> cl
          _ -> nil
        end
      end)
      |> Enum.filter(& &1)

    custom_responses =
      rules
      |> Enum.map(fn rule ->
        case ETS.get_custom_response_for_rule(rule.id) do
          {:ok, cr} -> cr
          _ -> nil
        end
      end)
      |> Enum.filter(& &1)

    socket =
      socket
      |> assign(:selected_route, route)
      |> assign(:rules, rules)
      |> assign(:rate_limits, rate_limits)
      |> assign(:ip_filters, ip_filters)
      |> assign(:time_restrictions, time_restrictions)
      |> assign(:concurrent_limits, concurrent_limits)
      |> assign(:custom_responses, custom_responses)

    {:noreply, socket}
  end

  def handle_event(
        "create_rate_limit",
        %{"rule_id" => rule_id, "requests" => requests, "window" => window},
        socket
      ) do
    rule_id = String.to_integer(rule_id)
    requests = String.to_integer(requests)
    window = String.to_integer(window)

    attrs = %{
      rule_id: rule_id,
      requests_per_window: requests,
      window_seconds: window,
      enabled: true
    }

    case RateLimit.changeset(%RateLimit{}, attrs) |> socket.assigns.repo.insert() do
      {:ok, _rate_limit} ->
        Cache.refresh_rule(socket.assigns.repo, rule_id)
        send(self(), {:refresh_route, socket.assigns.selected_route.id})
        {:noreply, put_flash(socket, :info, "Rate limit created successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create rate limit")}
    end
  end

  def handle_event(
        "create_ip_filter",
        %{"rule_id" => rule_id, "ip_address" => ip, "type" => type},
        socket
      ) do
    rule_id = String.to_integer(rule_id)
    type_atom = String.to_existing_atom(type)

    attrs = %{
      rule_id: rule_id,
      ip_address: ip,
      type: type_atom,
      enabled: true
    }

    case IpFilter.changeset(%IpFilter{}, attrs) |> socket.assigns.repo.insert() do
      {:ok, _ip_filter} ->
        Cache.refresh_rule(socket.assigns.repo, rule_id)
        send(self(), {:refresh_route, socket.assigns.selected_route.id})
        {:noreply, put_flash(socket, :info, "IP filter created successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create IP filter")}
    end
  end

  def handle_event("create_rule", %{"route_id" => route_id}, socket) do
    route_id = String.to_integer(route_id)

    # Check if a rule already exists for this route
    existing_rules = ETS.get_rules_for_route(route_id)

    if length(existing_rules) > 0 do
      {:noreply,
       put_flash(
         socket,
         :error,
         "A rule already exists for this route. Delete it first to create a new one."
       )}
    else
      attrs = %{
        route_id: route_id,
        enabled: true,
        priority: 0
      }

      case Rule.changeset(%Rule{}, attrs) |> socket.assigns.repo.insert() do
        {:ok, _rule} ->
          # Refresh all rules for this route
          refresh_rules_for_route(socket.assigns.repo, route_id)

          # Update socket directly with new rules
          route = Enum.find(socket.assigns.routes, &(&1.id == route_id))
          rules = ETS.get_rules_for_route(route_id)

          rate_limits =
            rules
            |> Enum.map(fn r ->
              case ETS.get_rate_limit_for_rule(r.id) do
                {:ok, rl} -> rl
                _ -> nil
              end
            end)
            |> Enum.filter(& &1)

          ip_filters =
            rules
            |> Enum.flat_map(fn r ->
              ETS.get_ip_filters_for_rule(r.id)
            end)

          socket =
            socket
            |> assign(:selected_route, route)
            |> assign(:rules, rules)
            |> assign(:rate_limits, rate_limits)
            |> assign(:ip_filters, ip_filters)

          {:noreply, put_flash(socket, :info, "Rule created successfully")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to create rule")}
      end
    end
  end

  def handle_event("delete_rule", %{"rule_id" => rule_id, "route_id" => route_id}, socket) do
    rule_id = String.to_integer(rule_id)
    route_id = String.to_integer(route_id)

    case socket.assigns.repo.get(Rule, rule_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Rule not found")}

      rule ->
        case socket.assigns.repo.delete(rule) do
          {:ok, _} ->
            # Clear the deleted rule from ETS
            :ets.match_delete(:route_shield_rules, {route_id, rule})

            # Refresh all rules for this route
            refresh_rules_for_route(socket.assigns.repo, route_id)

            # Update socket directly
            route = Enum.find(socket.assigns.routes, &(&1.id == route_id))
            rules = ETS.get_rules_for_route(route_id)

            rate_limits =
              rules
              |> Enum.map(fn r ->
                case ETS.get_rate_limit_for_rule(r.id) do
                  {:ok, rl} -> rl
                  _ -> nil
                end
              end)
              |> Enum.filter(& &1)

            ip_filters =
              rules
              |> Enum.flat_map(fn r ->
                ETS.get_ip_filters_for_rule(r.id)
              end)

            socket =
              socket
              |> assign(:selected_route, route)
              |> assign(:rules, rules)
              |> assign(:rate_limits, rate_limits)
              |> assign(:ip_filters, ip_filters)

            {:noreply, put_flash(socket, :info, "Rule deleted successfully")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to delete rule")}
        end
    end
  end

  def handle_event("toggle_global_blacklist", _params, socket) do
    {:noreply, update(socket, :show_global_blacklist, &(!&1))}
  end

  def handle_event(
        "create_global_blacklist",
        %{"ip_address" => ip_address, "description" => description},
        socket
      ) do
    attrs = %{
      ip_address: ip_address,
      description: description,
      enabled: true
    }

    case GlobalIpBlacklist.changeset(%GlobalIpBlacklist{}, attrs)
         |> socket.assigns.repo.insert() do
      {:ok, _entry} ->
        Cache.refresh_all(socket.assigns.repo)
        global_blacklist = socket.assigns.repo.all(GlobalIpBlacklist) |> Enum.filter(& &1.enabled)

        {:noreply,
         put_flash(
           socket |> assign(:global_blacklist, global_blacklist),
           :info,
           "Global blacklist entry created"
         )}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create global blacklist entry")}
    end
  end

  def handle_event("delete_global_blacklist", %{"id" => id}, socket) do
    case socket.assigns.repo.get(GlobalIpBlacklist, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Entry not found")}

      entry ->
        case socket.assigns.repo.delete(entry) do
          {:ok, _} ->
            Cache.refresh_all(socket.assigns.repo)

            global_blacklist =
              socket.assigns.repo.all(GlobalIpBlacklist) |> Enum.filter(& &1.enabled)

            {:noreply,
             put_flash(
               socket |> assign(:global_blacklist, global_blacklist),
               :info,
               "Global blacklist entry deleted"
             )}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete entry")}
        end
    end
  end

  def handle_event(
        "create_time_restriction",
        %{
          "rule_id" => rule_id,
          "start_time" => start_time,
          "end_time" => end_time,
          "days" => days
        },
        socket
      ) do
    rule_id = String.to_integer(rule_id)

    days_list =
      if days == "", do: [], else: String.split(days, ",") |> Enum.map(&String.to_integer/1)

    attrs = %{
      rule_id: rule_id,
      start_time: parse_time(start_time),
      end_time: parse_time(end_time),
      days_of_week: days_list,
      enabled: true
    }

    case TimeRestriction.changeset(%TimeRestriction{}, attrs) |> socket.assigns.repo.insert() do
      {:ok, _} ->
        Cache.refresh_rule(socket.assigns.repo, rule_id)
        send(self(), {:refresh_route, socket.assigns.selected_route.id})
        {:noreply, put_flash(socket, :info, "Time restriction created")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create time restriction")}
    end
  end

  def handle_event(
        "create_concurrent_limit",
        %{"rule_id" => rule_id, "max_concurrent" => max_concurrent},
        socket
      ) do
    rule_id = String.to_integer(rule_id)
    max_concurrent = String.to_integer(max_concurrent)

    attrs = %{
      rule_id: rule_id,
      max_concurrent: max_concurrent,
      enabled: true
    }

    case ConcurrentLimit.changeset(%ConcurrentLimit{}, attrs) |> socket.assigns.repo.insert() do
      {:ok, _} ->
        Cache.refresh_rule(socket.assigns.repo, rule_id)
        send(self(), {:refresh_route, socket.assigns.selected_route.id})
        {:noreply, put_flash(socket, :info, "Concurrent limit created")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create concurrent limit")}
    end
  end

  def handle_event(
        "create_custom_response",
        %{
          "rule_id" => rule_id,
          "status_code" => status_code,
          "message" => message,
          "content_type" => content_type
        },
        socket
      ) do
    rule_id = String.to_integer(rule_id)
    status_code = String.to_integer(status_code)

    attrs = %{
      rule_id: rule_id,
      status_code: status_code,
      message: message,
      content_type: content_type,
      enabled: true
    }

    case CustomResponse.changeset(%CustomResponse{}, attrs) |> socket.assigns.repo.insert() do
      {:ok, _} ->
        Cache.refresh_rule(socket.assigns.repo, rule_id)
        send(self(), {:refresh_route, socket.assigns.selected_route.id})
        {:noreply, put_flash(socket, :info, "Custom response created")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create custom response")}
    end
  end

  def handle_info({:refresh_route, route_id}, socket) do
    route = Enum.find(socket.assigns.routes, &(&1.id == route_id))
    rules = ETS.get_rules_for_route(route_id)

    rate_limits =
      rules
      |> Enum.map(fn rule ->
        case ETS.get_rate_limit_for_rule(rule.id) do
          {:ok, rl} -> rl
          _ -> nil
        end
      end)
      |> Enum.filter(& &1)

    ip_filters =
      rules
      |> Enum.flat_map(fn rule ->
        ETS.get_ip_filters_for_rule(rule.id)
      end)

    time_restrictions =
      rules
      |> Enum.flat_map(fn rule ->
        ETS.get_time_restrictions_for_rule(rule.id)
      end)

    concurrent_limits =
      rules
      |> Enum.map(fn rule ->
        case ETS.get_concurrent_limit_for_rule(rule.id) do
          {:ok, cl} -> cl
          _ -> nil
        end
      end)
      |> Enum.filter(& &1)

    custom_responses =
      rules
      |> Enum.map(fn rule ->
        case ETS.get_custom_response_for_rule(rule.id) do
          {:ok, cr} -> cr
          _ -> nil
        end
      end)
      |> Enum.filter(& &1)

    socket =
      socket
      |> assign(:selected_route, route)
      |> assign(:rules, rules)
      |> assign(:rate_limits, rate_limits)
      |> assign(:ip_filters, ip_filters)
      |> assign(:time_restrictions, time_restrictions)
      |> assign(:concurrent_limits, concurrent_limits)
      |> assign(:custom_responses, custom_responses)

    {:noreply, socket}
  end

  defp parse_time(time_string) when is_binary(time_string) do
    case Time.from_iso8601(time_string) do
      {:ok, time} -> time
      _ -> nil
    end
  end

  defp parse_time(_), do: nil

  defp format_time(time) when not is_nil(time) do
    Time.to_string(time)
  end

  defp format_time(_), do: ""

  defp format_days(days) when is_list(days) do
    day_names = %{
      1 => "Mon",
      2 => "Tue",
      3 => "Wed",
      4 => "Thu",
      5 => "Fri",
      6 => "Sat",
      7 => "Sun"
    }

    days |> Enum.map(&Map.get(day_names, &1, &1)) |> Enum.join(", ")
  end

  defp format_days(_), do: ""

  defp get_repo do
    Application.get_env(:route_shield, :repo) ||
      raise "RouteShield repo not configured. Set config :route_shield, repo: YourApp.Repo"
  end

  defp refresh_rules_for_route(repo, route_id) do
    # Load all rules for this route from database
    rules = repo.all(from(r in Rule, where: r.route_id == ^route_id))

    # Clear existing rules for this route in ETS by deleting all objects with this route_id
    :ets.match_delete(:route_shield_rules, {route_id, :_})

    # Store all rules in ETS
    Enum.each(rules, &ETS.store_rule/1)

    # Refresh rate limits and IP filters for all rules
    Enum.each(rules, fn rule ->
      Cache.refresh_rule(repo, rule.id)
    end)
  end

  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>RouteShield Dashboard</title>
      <script src="https://cdn.tailwindcss.com"></script>
    </head>
    <body>
    <div class="min-h-screen bg-gray-50">
      <!-- Header -->
      <header class="bg-white shadow">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-4">
              <svg width="60" height="60" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg" class="flex-shrink-0">
                <defs>
                  <linearGradient id="shieldGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                    <stop offset="0%" style="stop-color:#3B82F6;stop-opacity:1" />
                    <stop offset="100%" style="stop-color:#1E40AF;stop-opacity:1" />
                  </linearGradient>
                </defs>
                <path d="M100 20 L40 45 L40 90 C40 130 60 165 100 180 C140 165 160 130 160 90 L160 45 Z" fill="url(#shieldGradient)" stroke="#1E3A8A" stroke-width="3" stroke-linejoin="round"/>
                <path d="M100 70 L80 85 L100 100 L120 85 Z" fill="white" opacity="0.9"/>
                <circle cx="100" cy="120" r="8" fill="white" opacity="0.9"/>
              </svg>
              <div>
                <h1 class="text-3xl font-bold text-gray-900 flex items-center gap-2">
                  RouteShield Dashboard
                </h1>
                <p class="mt-2 text-sm text-gray-600">Manage route protection and access rules</p>
              </div>
            </div>
            <button
              phx-click="toggle_global_blacklist"
              class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
            >
              <%= if @show_global_blacklist, do: "Hide", else: "Show" %> Global Blacklist
            </button>
          </div>
        </div>
      </header>

      <!-- Global Blacklist Section -->
      <%= if @show_global_blacklist do %>
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div class="bg-white rounded-lg shadow">
            <div class="px-6 py-4 border-b border-gray-200">
              <h2 class="text-lg font-semibold text-gray-900">Global IP Blacklist</h2>
              <p class="text-sm text-gray-500 mt-1">Applies to all routes</p>
            </div>
            <div class="px-6 py-4">
              <form phx-submit="create_global_blacklist" class="mb-4">
                <div class="flex gap-2">
                  <input
                    type="text"
                    name="ip_address"
                    placeholder="IP or CIDR (e.g., 192.168.1.0/24)"
                    class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                    required
                  />
                  <input
                    type="text"
                    name="description"
                    placeholder="Description (optional)"
                    class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                  />
                  <button
                    type="submit"
                    class="px-4 py-2 text-sm font-medium text-white bg-red-600 hover:bg-red-700 rounded-md"
                  >
                    Add to Blacklist
                  </button>
                </div>
              </form>
              <div class="space-y-2">
                <%= for entry <- @global_blacklist do %>
                  <div class="flex items-center justify-between p-3 bg-gray-50 rounded">
                    <div>
                      <span class="font-mono text-sm"><%= entry.ip_address %></span>
                      <%= if entry.description do %>
                        <p class="text-xs text-gray-500 mt-1"><%= entry.description %></p>
                      <% end %>
                    </div>
                    <button
                      phx-click="delete_global_blacklist"
                      phx-value-id={entry.id}
                      class="text-red-600 hover:text-red-900 text-sm font-medium"
                      onclick="return confirm('Are you sure?')"
                    >
                      Delete
                    </button>
                  </div>
                <% end %>
                <%= if length(@global_blacklist) == 0 do %>
                  <p class="text-sm text-gray-500 text-center py-4">No global blacklist entries</p>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <!-- Routes List -->
          <div class="lg:col-span-1">
            <div class="bg-white rounded-lg shadow">
              <div class="px-6 py-4 border-b border-gray-200">
                <h2 class="text-lg font-semibold text-gray-900">Routes</h2>
                <p class="text-sm text-gray-500 mt-1"><%= length(@routes) %> routes discovered</p>
              </div>
              <div class="divide-y divide-gray-200 max-h-96 overflow-y-auto">
                <%= for route <- @routes do %>
                  <button
                    phx-click="select_route"
                    phx-value-route_id={route.id}
                    class={[
                      "w-full px-6 py-4 text-left hover:bg-gray-50 transition-colors",
                      if(@selected_route && @selected_route.id == route.id, do: "bg-blue-50 border-l-4 border-blue-500", else: "")
                    ]}
                  >
                    <div class="flex items-center justify-between">
                      <div>
                        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                          <%= route.method %>
                        </span>
                        <p class="mt-1 text-sm font-medium text-gray-900"><%= route.path_pattern %></p>
                        <%= if route.controller do %>
                          <p class="text-xs text-gray-500 mt-1"><%= route.controller %></p>
                        <% end %>
                      </div>
                    </div>
                  </button>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Route Details -->
          <div class="lg:col-span-2">
            <%= if @selected_route do %>
              <div class="space-y-6">
                <!-- Route Info -->
                <div class="bg-white rounded-lg shadow">
                  <div class="px-6 py-4 border-b border-gray-200">
                    <h2 class="text-lg font-semibold text-gray-900">Route Details</h2>
                  </div>
                  <div class="px-6 py-4">
                    <dl class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                      <div>
                        <dt class="text-sm font-medium text-gray-500">Method</dt>
                        <dd class="mt-1 text-sm text-gray-900">
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                            <%= @selected_route.method %>
                          </span>
                        </dd>
                      </div>
                      <div>
                        <dt class="text-sm font-medium text-gray-500">Path Pattern</dt>
                        <dd class="mt-1 text-sm text-gray-900 font-mono"><%= @selected_route.path_pattern %></dd>
                      </div>
                      <%= if @selected_route.controller do %>
                        <div>
                          <dt class="text-sm font-medium text-gray-500">Controller</dt>
                          <dd class="mt-1 text-sm text-gray-900"><%= @selected_route.controller %></dd>
                        </div>
                      <% end %>
                      <%= if @selected_route.action do %>
                        <div>
                          <dt class="text-sm font-medium text-gray-500">Action</dt>
                          <dd class="mt-1 text-sm text-gray-900"><%= @selected_route.action %></dd>
                        </div>
                      <% end %>
                    </dl>
                  </div>
                </div>

                <!-- Rules Section -->
                <div class="bg-white rounded-lg shadow">
                  <div class="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
                    <h2 class="text-lg font-semibold text-gray-900">
                      Rules
                      <%= if length(@rules) > 0 do %>
                        <span class="ml-2 text-sm font-normal text-gray-500">(<%= length(@rules) %>)</span>
                      <% end %>
                    </h2>
                    <%= if length(@rules) == 0 do %>
                      <button
                        phx-click="create_rule"
                        phx-value-route_id={@selected_route.id}
                        class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                      >
                        Create Rule
                      </button>
                    <% end %>
                  </div>

                  <%= if length(@rules) == 0 do %>
                    <div class="px-6 py-8 text-center">
                      <p class="text-sm text-gray-500 mb-4">No rules configured for this route</p>
                      <p class="text-xs text-gray-400">Click "Create Rule" above to add protection rules</p>
                    </div>
                  <% else %>
                    <div class="px-6 py-4 space-y-4">
                      <%= for rule <- @rules do %>
                        <div class="border border-gray-200 rounded-lg p-4">
                          <div class="flex items-center justify-between mb-4">
                            <div>
                              <h3 class="text-sm font-medium text-gray-900">Rule #<%= rule.id %></h3>
                              <p class="text-xs text-gray-500">Priority: <%= rule.priority %></p>
                            </div>
                            <div class="flex items-center gap-2">
                              <span class={[
                                "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                                if(rule.enabled, do: "bg-green-100 text-green-800", else: "bg-gray-100 text-gray-800")
                              ]}>
                                <%= if rule.enabled, do: "Enabled", else: "Disabled" %>
                              </span>
                              <button
                                phx-click="delete_rule"
                                phx-value-rule_id={rule.id}
                                phx-value-route_id={@selected_route.id}
                                class="inline-flex items-center px-2 py-1 text-xs font-medium text-red-600 hover:text-red-700 hover:bg-red-50 rounded"
                                onclick="return confirm('Are you sure you want to delete this rule?')"
                              >
                                Delete
                              </button>
                            </div>
                          </div>

                          <!-- Rate Limit -->
                          <%= if rate_limit = Enum.find(@rate_limits, &(&1.rule_id == rule.id)) do %>
                            <div class="mb-3 p-3 bg-blue-50 rounded">
                              <p class="text-xs font-medium text-blue-900 mb-1">Rate Limit</p>
                              <p class="text-sm text-blue-700">
                                <%= rate_limit.requests_per_window %> requests per <%= rate_limit.window_seconds %> seconds
                              </p>
                            </div>
                          <% else %>
                            <form phx-submit="create_rate_limit" class="mb-3">
                              <input type="hidden" name="rule_id" value={rule.id} />
                              <div class="flex gap-2">
                                <input
                                  type="number"
                                  name="requests"
                                  placeholder="Requests"
                                  class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                  required
                                />
                                <input
                                  type="number"
                                  name="window"
                                  placeholder="Seconds"
                                  class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                  required
                                />
                                <button
                                  type="submit"
                                  class="px-4 py-2 text-sm font-medium text-blue-600 hover:text-blue-700"
                                >
                                  Add Rate Limit
                                </button>
                              </div>
                            </form>
                          <% end %>

                          <!-- IP Filters -->
                          <div>
                            <p class="text-xs font-medium text-gray-700 mb-2">IP Filters</p>
                            <%= if Enum.any?(@ip_filters, &(&1.rule_id == rule.id)) do %>
                              <div class="space-y-1 mb-2">
                                <%= for ip_filter <- Enum.filter(@ip_filters, &(&1.rule_id == rule.id)) do %>
                                  <div class="flex items-center justify-between text-xs p-2 bg-gray-50 rounded">
                                    <span class="font-mono"><%= ip_filter.ip_address %></span>
                                    <span class={[
                                      "px-2 py-0.5 rounded text-xs",
                                      if(ip_filter.type == :whitelist, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800")
                                    ]}>
                                      <%= ip_filter.type %>
                                    </span>
                                  </div>
                                <% end %>
                              </div>
                            <% end %>
                            <form phx-submit="create_ip_filter">
                              <input type="hidden" name="rule_id" value={rule.id} />
                              <div class="flex gap-2">
                                <input
                                  type="text"
                                  name="ip_address"
                                  placeholder="IP or CIDR (e.g., 192.168.1.0/24)"
                                  class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                  required
                                />
                                <select
                                  name="type"
                                  class="rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                  required
                                >
                                  <option value="whitelist">Whitelist</option>
                                  <option value="blacklist">Blacklist</option>
                                </select>
                                <button
                                  type="submit"
                                  class="px-4 py-2 text-sm font-medium text-blue-600 hover:text-blue-700"
                                >
                                  Add
                                </button>
                              </div>
                            </form>
                          </div>

                          <!-- Time Restrictions -->
                          <div class="mt-3">
                            <p class="text-xs font-medium text-gray-700 mb-2">Time Restrictions</p>
                            <%= if Enum.any?(@time_restrictions, &(&1.rule_id == rule.id)) do %>
                              <div class="space-y-1 mb-2">
                                <%= for tr <- Enum.filter(@time_restrictions, &(&1.rule_id == rule.id)) do %>
                                  <div class="p-2 bg-purple-50 rounded text-xs">
                                    <%= if tr.start_time && tr.end_time do %>
                                      <span class="font-medium">Time:</span> <%= format_time(tr.start_time) %> - <%= format_time(tr.end_time) %>
                                    <% end %>
                                    <%= if tr.days_of_week && length(tr.days_of_week) > 0 do %>
                                      <span class="ml-2">
                                        <span class="font-medium">Days:</span> <%= format_days(tr.days_of_week) %>
                                      </span>
                                    <% end %>
                                  </div>
                                <% end %>
                              </div>
                            <% end %>
                            <form phx-submit="create_time_restriction" class="text-xs">
                              <input type="hidden" name="rule_id" value={rule.id} />
                              <div class="grid grid-cols-3 gap-2">
                                <input
                                  type="time"
                                  name="start_time"
                                  placeholder="Start"
                                  class="rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                />
                                <input
                                  type="time"
                                  name="end_time"
                                  placeholder="End"
                                  class="rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                />
                                <input
                                  type="text"
                                  name="days"
                                  placeholder="Days (1-7, comma-separated)"
                                  class="rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                />
                              </div>
                              <button
                                type="submit"
                                class="mt-2 w-full px-3 py-1 text-xs font-medium text-purple-600 hover:text-purple-700 bg-purple-50 hover:bg-purple-100 rounded"
                              >
                                Add Time Restriction
                              </button>
                            </form>
                          </div>

                          <!-- Concurrent Limits -->
                          <%= if concurrent_limit = Enum.find(@concurrent_limits, &(&1.rule_id == rule.id)) do %>
                            <div class="mt-3 p-3 bg-yellow-50 rounded">
                              <p class="text-xs font-medium text-yellow-900 mb-1">Concurrent Limit</p>
                              <p class="text-sm text-yellow-700">
                                Max <%= concurrent_limit.max_concurrent %> concurrent requests per IP
                              </p>
                            </div>
                          <% else %>
                            <form phx-submit="create_concurrent_limit" class="mt-3">
                              <input type="hidden" name="rule_id" value={rule.id} />
                              <div class="flex gap-2">
                                <input
                                  type="number"
                                  name="max_concurrent"
                                  placeholder="Max concurrent"
                                  min="1"
                                  class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                  required
                                />
                                <button
                                  type="submit"
                                  class="px-4 py-2 text-sm font-medium text-yellow-600 hover:text-yellow-700"
                                >
                                  Add Concurrent Limit
                                </button>
                              </div>
                            </form>
                          <% end %>

                          <!-- Custom Response -->
                          <%= if custom_response = Enum.find(@custom_responses, &(&1.rule_id == rule.id)) do %>
                            <div class="mt-3 p-3 bg-indigo-50 rounded">
                              <p class="text-xs font-medium text-indigo-900 mb-1">Custom Response</p>
                              <p class="text-sm text-indigo-700">
                                Status: <%= custom_response.status_code %>, Type: <%= custom_response.content_type %>
                              </p>
                              <%= if custom_response.message do %>
                                <p class="text-xs text-indigo-600 mt-1"><%= custom_response.message %></p>
                              <% end %>
                            </div>
                          <% else %>
                            <form phx-submit="create_custom_response" class="mt-3">
                              <input type="hidden" name="rule_id" value={rule.id} />
                              <div class="space-y-2">
                                <div class="flex gap-2">
                                  <input
                                    type="number"
                                    name="status_code"
                                    placeholder="Status Code"
                                    min="400"
                                    max="599"
                                    class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                    required
                                  />
                                  <select
                                    name="content_type"
                                    class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                    required
                                  >
                                    <option value="application/json">JSON</option>
                                    <option value="text/html">HTML</option>
                                    <option value="text/plain">Plain Text</option>
                                  </select>
                                </div>
                                <input
                                  type="text"
                                  name="message"
                                  placeholder="Error message (optional)"
                                  class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                                />
                                <button
                                  type="submit"
                                  class="w-full px-4 py-2 text-sm font-medium text-indigo-600 hover:text-indigo-700"
                                >
                                  Add Custom Response
                                </button>
                              </div>
                            </form>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            <% else %>
              <div class="bg-white rounded-lg shadow p-12 text-center">
                <p class="text-gray-500">Select a route to view and manage its rules</p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    </body>
    </html>
    """
  end
end
