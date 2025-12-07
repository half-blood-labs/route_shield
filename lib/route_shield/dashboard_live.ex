defmodule RouteShield.DashboardLive do
  @moduledoc """
  Phoenix LiveView dashboard for managing RouteShield rules.
  """

  use Phoenix.LiveView
  alias RouteShield.Storage.ETS
  alias RouteShield.Storage.Cache
  alias RouteShield.Schema.{Route, Rule, RateLimit, IpFilter}

  def mount(_params, _session, socket) do
    repo = get_repo()
    routes = repo.all(Route) |> Enum.sort_by(&{&1.method, &1.path_pattern})

    Enum.each(routes, &ETS.store_route/1)

    socket =
      socket
      |> assign(:routes, routes)
      |> assign(:selected_route, nil)
      |> assign(:rules, [])
      |> assign(:rate_limits, [])
      |> assign(:ip_filters, [])
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

    socket =
      socket
      |> assign(:selected_route, route)
      |> assign(:rules, rules)
      |> assign(:rate_limits, rate_limits)
      |> assign(:ip_filters, ip_filters)

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

    attrs = %{
      route_id: route_id,
      enabled: true,
      priority: 0
    }

    case Rule.changeset(%Rule{}, attrs) |> socket.assigns.repo.insert() do
      {:ok, _rule} ->
        Cache.refresh_rule(socket.assigns.repo, route_id)
        send(self(), {:refresh_route, route_id})
        {:noreply, put_flash(socket, :info, "Rule created successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create rule")}
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

    socket =
      socket
      |> assign(:selected_route, route)
      |> assign(:rules, rules)
      |> assign(:rate_limits, rate_limits)
      |> assign(:ip_filters, ip_filters)

    {:noreply, socket}
  end

  defp get_repo do
    Application.get_env(:route_shield, :repo) ||
      raise "RouteShield repo not configured. Set config :route_shield, repo: YourApp.Repo"
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Header -->
      <header class="bg-white shadow">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <h1 class="text-3xl font-bold text-gray-900">RouteShield Dashboard</h1>
          <p class="mt-2 text-sm text-gray-600">Manage route protection and access rules</p>
        </div>
      </header>

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
                    <h2 class="text-lg font-semibold text-gray-900">Rules</h2>
                    <button
                      phx-click="create_rule"
                      phx-value-route_id={@selected_route.id}
                      class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                    >
                      Create Rule
                    </button>
                  </div>

                  <%= if length(@rules) == 0 do %>
                    <div class="px-6 py-8 text-center">
                      <p class="text-sm text-gray-500">No rules configured for this route</p>
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
                            <span class={[
                              "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                              if(rule.enabled, do: "bg-green-100 text-green-800", else: "bg-gray-100 text-gray-800")
                            ]}>
                              <%= if rule.enabled, do: "Enabled", else: "Disabled" %>
                            </span>
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
                            <%= rule_ip_filters = Enum.filter(@ip_filters, &(&1.rule_id == rule.id)) %>
                            <%= if length(rule_ip_filters) > 0 do %>
                              <div class="space-y-1 mb-2">
                                <%= for ip_filter <- rule_ip_filters do %>
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
    """
  end
end
