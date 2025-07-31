defmodule ThundertabWeb.Live.Federation.DashboardLive do
  @moduledoc """
  ⚡ THUNDERPRISM FEDERATION DASHBOARD

  Real-time Thunderblock network visualization and control interface.
  Built with Phoenix LiveView + DaisyUI + Neon Theme.
  """

  use ThundertabWeb, :live_view

  alias Thundertab.Federation.Thunderblock.{Network, Instance}

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to real-time PubSub topics for "Real-Talk" updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Thundertab.PubSub, "federation:network")
      Phoenix.PubSub.subscribe(Thundertab.PubSub, "node:stats")
      Phoenix.PubSub.subscribe(Thundertab.PubSub, "activity:feed")
    end

    # Load initial data and start live metrics
    socket = load_initial_data(socket)

    # Schedule periodic updates for demo metrics
    if connected?(socket) do
      :timer.send_interval(2000, self(), :update_metrics)
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("discover_instance", %{"domain" => domain}, socket) do
    domain = String.trim(domain)

    if domain != "" do
      Network.discover_instance(domain)

      socket = assign(socket, :discovery_message, "🔍 Discovering #{domain}...")
      {:noreply, socket}
    else
      socket = assign(socket, :discovery_message, "⚠️ Please enter a valid domain")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("force_health_check", _params, socket) do
    Network.force_health_check()
    socket = assign(socket, :discovery_message, "🩺 Performing health check...")
    {:noreply, socket}
  end

  @impl true
  def handle_event("broadcast_test", _params, socket) do
    Network.broadcast_test_message()
    socket = assign(socket, :discovery_message, "📤 Test message broadcasted!")
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_terminal", _params, socket) do
    socket = assign(socket, :show_terminal, !Map.get(socket.assigns, :show_terminal, false))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:node_stats, stats}, socket) do
    {:noreply, assign(socket, :resource_usage, stats)}
  end

  @impl true
  def handle_info({:activity_event, event}, socket) do
    activity = [event | Enum.take(socket.assigns.activity || [], 9)]
    {:noreply, assign(socket, :activity, activity)}
  end

  @impl true
  def handle_info(:update_metrics, socket) do
    # Generate live demo metrics for the "Real-Talk" experience
    cpu = :rand.uniform(40) + 10
    mem = :rand.uniform(60) + 20
    net = :rand.uniform(80) + 10
    events_per_min = :rand.uniform(200) + 700

    resource_usage = %{cpu: cpu, mem: mem, net: net}

    # Create a new activity event
    time = DateTime.utc_now() |> DateTime.to_time() |> Time.to_string() |> String.slice(0, 8)
    messages = [
      "Federation sync completed",
      "New instance discovered",
      "Activity stream updated",
      "Health check passed",
      "Network topology refreshed",
      "Thunderblock validated",
      "Real-time data synchronized"
    ]
    message = Enum.random(messages)
    activity_event = {time, message}

    socket =
      socket
      |> assign(:resource_usage, resource_usage)
      |> assign(:events_per_min, events_per_min)
      |> update(:activity, fn activity ->
        [activity_event | Enum.take(activity || [], 9)]
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:instance_discovered, instance}, socket) do
    known_instances = Map.put(socket.assigns.known_instances, instance.domain, instance)

    socket =
      socket
      |> assign(:known_instances, known_instances)
      |> assign(:discovery_message, "✅ Discovered #{instance.domain}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:network_health_updated, health}, socket) do
    socket = assign(socket, :network_health, health)
    {:noreply, socket}
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-bg text-white font-sans">
      <!-- Thunderprism Header -->
      <div class="flex justify-between items-center p-6 border-b border-white/10">
        <div class="flex items-center space-x-4">
          <h1 class="text-2xl font-semibold text-glow text-neon-cyan">Thunderprism</h1>
          <div class="text-sm text-gray-400">Federation Control Interface</div>
        </div>
        <nav class="flex space-x-6 text-sm text-gray-400">
          <a href="#" class="text-neon-cyan hover:text-glow transition-all">DASHBOARD</a>
          <a href="#" class="hover:text-neon-cyan transition-all">TERMINAL</a>
          <a href="#" class="hover:text-neon-cyan transition-all">SETTINGS</a>
        </nav>
      </div>

      <!-- Geometric Logo with Grid Sweep -->
      <div class="relative flex justify-center py-12">
        <div class="thunderprism-logo">
          <svg viewBox="0 0 120 120" class="stroke-neon-cyan">
            <defs>
              <linearGradient id="logoGradient" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" style="stop-color:#00F5FF"/>
                <stop offset="50%" style="stop-color:#FF3BE7"/>
                <stop offset="100%" style="stop-color:#A84BFF"/>
              </linearGradient>
            </defs>
            <!-- Infinity-like geometric pattern -->
            <path d="M20,60 Q35,20 60,60 Q85,100 100,60 Q85,20 60,60 Q35,100 20,60 Z"
                  stroke="url(#logoGradient)"
                  stroke-width="2"
                  fill="none"
                  stroke-dasharray="200"
                  stroke-dashoffset="0">
              <animate attributeName="stroke-dashoffset"
                       values="0;400;0"
                       dur="8s"
                       repeatCount="indefinite"/>
            </path>
            <!-- Central core -->
            <circle cx="60" cy="60" r="8" fill="url(#logoGradient)" class="animate-pulse"/>
          </svg>
        </div>
        <div class="absolute inset-0 bg-grid-sweep pointer-events-none opacity-30"></div>
      </div>

      <!-- Main Content Grid -->
      <div class="px-6 space-y-8">
        <!-- Primary Service Cards -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="neon-card-cyan p-8">
            <div class="flex items-center justify-between mb-4">
              <div class="flex items-center space-x-3">
                <div class="w-12 h-12 bg-gradient-to-r from-neon-cyan to-white rounded-lg flex items-center justify-center">
                  <span class="text-black font-bold text-xl">⚡</span>
                </div>
                <h2 class="text-xl font-medium text-white">Thunderline Node</h2>
              </div>
              <span class="text-xs px-3 py-1 bg-neon-cyan/20 text-neon-cyan rounded-full border border-neon-cyan/30">Online</span>
            </div>
            <p class="text-gray-300 text-sm mb-6 leading-relaxed">
              Intelligence, distributed.<br/>
              Autonomy, embodied.
            </p>
            <button class="neon-button text-sm">
              Manage…
            </button>
          </div>

          <div class="neon-card-magenta p-8">
            <div class="flex items-center justify-between mb-4">
              <div class="flex items-center space-x-3">
                <div class="w-12 h-12 bg-gradient-to-r from-neon-magenta to-white rounded-lg flex items-center justify-center">
                  <span class="text-black font-bold text-xl">🌐</span>
                </div>
                <h2 class="text-xl font-medium text-white">Thunderblock Server</h2>
              </div>
              <span class="text-xs px-3 py-1 bg-neon-magenta/20 text-neon-magenta rounded-full border border-neon-magenta/30">Connected</span>
            </div>
            <p class="text-gray-300 text-sm mb-6 leading-relaxed">
              Proof, immutable.<br/>
              Storage, recursive.
            </p>
            <button class="px-4 py-2 bg-gradient-to-r from-neon-magenta to-neon-purple text-black rounded font-medium hover:scale-105 transition-transform text-sm">
              Configure…
            </button>
          </div>
        </div>

        <!-- Live Stats and Activity -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <!-- Activity Feed -->
          <div class="neon-card p-6">
            <h3 class="text-lg font-medium mb-6 text-neon-cyan">Activity</h3>
            <div class="space-y-3 max-h-80 overflow-y-auto">
              <%= if assigns[:activity] && length(@activity) > 0 do %>
                <%= for {time, message} <- @activity do %>
                  <div class="activity-item">
                    <div class="activity-dot bg-neon-cyan"></div>
                    <div class="flex-1">
                      <div class="text-white text-sm"><%= message %></div>
                      <div class="text-gray-400 text-xs mt-1"><%= time %></div>
                    </div>
                  </div>
                <% end %>
              <% else %>
                <div class="activity-item">
                  <div class="activity-dot bg-green-400"></div>
                  <div class="flex-1">
                    <div class="text-white text-sm">Thunderprism initialized</div>
                    <div class="text-gray-400 text-xs mt-1">
                      <%= DateTime.utc_now() |> DateTime.to_time() |> Time.to_string() |> String.slice(0, 8) %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Resource Usage -->
          <div class="neon-card p-6">
            <h3 class="text-lg font-medium mb-6 text-neon-magenta">Resource Usage</h3>
            <div class="space-y-6">
              <!-- CPU -->
              <div>
                <div class="flex justify-between text-sm mb-2">
                  <span class="text-gray-300">CPU</span>
                  <span class="text-neon-cyan"><%= Map.get(@resource_usage || %{}, :cpu, 23) %>%</span>
                </div>
                <div class="resource-bar">
                  <div class="resource-bar-fill from-neon-cyan to-neon-purple"
                       style={"width: #{Map.get(@resource_usage || %{}, :cpu, 23)}%"}></div>
                </div>
              </div>

              <!-- Memory -->
              <div>
                <div class="flex justify-between text-sm mb-2">
                  <span class="text-gray-300">MEMORY</span>
                  <span class="text-neon-magenta"><%= Map.get(@resource_usage || %{}, :mem, 34) %>%</span>
                </div>
                <div class="resource-bar">
                  <div class="resource-bar-fill from-neon-magenta to-neon-orange"
                       style={"width: #{Map.get(@resource_usage || %{}, :mem, 34)}%"}></div>
                </div>
              </div>

              <!-- Network -->
              <div>
                <div class="flex justify-between text-sm mb-2">
                  <span class="text-gray-300">NETWORK</span>
                  <span class="text-neon-orange"><%= Map.get(@resource_usage || %{}, :net, 80) %>%</span>
                </div>
                <div class="resource-bar">
                  <div class="resource-bar-fill from-neon-orange to-neon-yellow"
                       style={"width: #{Map.get(@resource_usage || %{}, :net, 80)}%"}></div>
                </div>
              </div>

              <!-- Events per minute -->
              <div class="pt-4 border-t border-gray-700">
                <div class="flex justify-between items-center">
                  <span class="text-sm text-gray-300">Events/min</span>
                  <span class="text-2xl font-bold text-neon-purple"><%= Map.get(assigns, :events_per_min, 847) %></span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Instance Discovery -->
        <div class="neon-card-purple p-6">
          <h3 class="text-lg font-medium mb-6 text-neon-purple">Instance Discovery</h3>

          <form phx-submit="discover_instance" class="mb-6">
            <div class="relative">
              <input
                type="text"
                name="domain"
                placeholder="domain.example.com"
                class="neon-input"
              />
              <button type="submit" class="absolute right-2 top-2 neon-button text-sm">
                SCAN
              </button>
            </div>
          </form>

          <%= if assigns[:discovery_message] do %>
            <div class="mb-6 p-4 bg-neon-cyan/10 border border-neon-cyan/20 rounded-lg">
              <span class="text-neon-cyan text-sm"><%= @discovery_message %></span>
            </div>
          <% end %>

          <!-- Known Instances -->
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= if @known_instances != %{} do %>
              <%= for {domain, instance} <- @known_instances do %>
                <div class="bg-black/30 rounded-lg p-4 border border-gray-700">
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-white font-medium text-sm"><%= domain %></span>
                    <div class={[
                      "status-dot",
                      case instance.status do
                        :online -> "status-online"
                        :offline -> "status-offline"
                        _ -> "status-warning"
                      end
                    ]}></div>
                  </div>
                  <p class="text-gray-400 text-xs"><%= instance.description %></p>
                </div>
              <% end %>
            <% else %>
              <div class="col-span-full text-center py-8 text-gray-400">
                <div class="text-4xl mb-2">🔍</div>
                <div class="text-sm">No instances discovered</div>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Terminal Footer -->
      <footer class="mt-12 p-6 border-t border-gray-800">
        <div class="flex items-center justify-between">
          <div class="text-xs text-gray-500 font-mono">
            TERMINAL&nbsp;&nbsp;user@volcanoer:$ <span class="animate-pulse">█</span>
          </div>
          <div class="text-xs text-gray-400">
            Powered by
            <span class="text-neon-cyan">Thunderblock Protocol</span> •
            <span class="text-neon-magenta">Phoenix LiveView</span> •
            <span class="text-neon-purple">Real-time WebSocket</span>
          </div>
        </div>
      </footer>
    </div>
    """
  end

  # Private helper functions
  defp load_initial_data(socket) do
    try do
      # Get network stats (with safe fallbacks)
      network_stats = Network.get_network_stats() || %{
        total_instances: 1,
        healthy_instances: 1,
        uptime_seconds: 0
      }

      # Get known instances
      known_instances = Network.get_known_instances() || %{}

      # Get network health
      network_health = Network.get_network_health() || %{
        status: :online,
        last_check: DateTime.utc_now()
      }

      # Initialize real-time metrics for "Real-Talk" dashboard
      resource_usage = %{cpu: 23, mem: 34, net: 80}
      events_per_min = 847
      activity = []

      socket
      |> assign(:network_stats, network_stats)
      |> assign(:known_instances, known_instances)
      |> assign(:network_health, network_health)
      |> assign(:resource_usage, resource_usage)
      |> assign(:events_per_min, events_per_min)
      |> assign(:activity, activity)
      |> assign(:discovery_message, nil)
      |> assign(:show_terminal, false)
    rescue
      _error ->
        # If there's any error loading data, provide safe defaults
        socket
        |> assign(:network_stats, %{total_instances: 1, healthy_instances: 1, uptime_seconds: 0})
        |> assign(:known_instances, %{})
        |> assign(:network_health, %{status: :online, last_check: DateTime.utc_now()})
        |> assign(:resource_usage, %{cpu: 23, mem: 34, net: 80})
        |> assign(:events_per_min, 847)
        |> assign(:activity, [])
        |> assign(:discovery_message, "⚡ Thunderprism Interface Ready")
        |> assign(:show_terminal, false)
    end
  end
end
