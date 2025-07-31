defmodule Thundertab.Federation.Thunderblock.Network do
  @moduledoc """
  Thunderblock network topology and health management.

  Manages the overall health and topology of the Thunderblock
  federation network, including discovery and monitoring.
  """

  use GenServer
  require Logger

  alias Thundertab.Federation.Thunderblock.Instance
  alias Thundertab.Federation.ActivityPub.{WebFinger, Federator}

  defstruct [
    :local_instance,
    :known_instances,
    :network_health,
    :topology_graph,
    :last_discovery,
    :stats
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get all known instances
  """
  def get_known_instances do
    GenServer.call(__MODULE__, :get_known_instances)
  end

  @doc """
  Get network health status
  """
  def get_network_health do
    GenServer.call(__MODULE__, :get_network_health)
  end

  @doc """
  Get network topology for visualization
  """
  def get_network_topology do
    GenServer.call(__MODULE__, :get_network_topology)
  end

  @doc """
  Add a new instance to the network
  """
  def discover_instance(domain) do
    GenServer.cast(__MODULE__, {:discover_instance, domain})
  end

  @doc """
  Force network health check
  """
  def force_health_check do
    GenServer.cast(__MODULE__, :force_health_check)
  end

  @doc """
  Get network statistics
  """
  def get_network_stats do
    GenServer.call(__MODULE__, :get_network_stats)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    Logger.info("🌐 Thunderblock Network Manager starting...")

    # Initialize local instance
    local_config = Keyword.get(opts, :local_instance, [])
    {:ok, local_instance} = Instance.create_local_instance(local_config)

    state = %__MODULE__{
      local_instance: local_instance,
      known_instances: %{},
      network_health: %{
        status: :initializing,
        last_check: DateTime.utc_now(),
        healthy_instances: 0,
        health_percentage: 0
      },
      topology_graph: %{nodes: [], edges: []},
      last_discovery: nil,
      stats: %{
        total_instances: 0,
        healthy_instances: 0,
        messages_sent: 0,
        messages_received: 0,
        uptime: System.system_time(:second)
      }
    }

    # Schedule periodic tasks
    :timer.send_interval(30_000, :health_check_cycle)
    :timer.send_interval(300_000, :discovery_cycle)  # 5 minutes
    :timer.send_interval(10_000, :broadcast_stats)   # 10 seconds

    # Announce our presence
    announce_presence()

    {:ok, state}
  end

  @impl true
  def handle_call(:get_known_instances, _from, state) do
    instances = Map.values(state.known_instances)
    {:reply, instances, state}
  end

  @impl true
  def handle_call(:get_network_health, _from, state) do
    {:reply, state.network_health, state}
  end

  @impl true
  def handle_call(:get_network_topology, _from, state) do
    {:reply, state.topology_graph, state}
  end

  @impl true
  def handle_call(:get_network_stats, _from, state) do
    current_stats = calculate_current_stats(state)
    {:reply, current_stats, state}
  end

  @impl true
  def handle_cast({:discover_instance, domain}, state) do
    case WebFinger.discover_instance(domain) do
      {:ok, webfinger_data} ->
        case WebFinger.resolve_actor_url(webfinger_data) do
          {:ok, actor_url} ->
            case Instance.from_actor_url(actor_url) do
              {:ok, instance} ->
                new_known_instances = Map.put(state.known_instances, domain, instance)
                new_state = %{state | known_instances: new_known_instances}

                # Update topology
                new_state = update_network_topology(new_state)

                # Broadcast discovery
                broadcast_network_update(:instance_discovered, instance)

                Logger.info("🔍 Discovered new Thunderblock: #{domain}")
                {:noreply, new_state}

              error ->
                Logger.warn("Failed to create instance from #{domain}: #{inspect(error)}")
                {:noreply, state}
            end

          error ->
            Logger.warn("Failed to resolve actor for #{domain}: #{inspect(error)}")
            {:noreply, state}
        end

      error ->
        Logger.warn("Failed to discover #{domain}: #{inspect(error)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast(:force_health_check, state) do
    new_state = perform_health_check_cycle(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:health_check_cycle, state) do
    new_state = perform_health_check_cycle(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:discovery_cycle, state) do
    # Try to discover new instances through existing ones
    new_state = perform_discovery_cycle(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:broadcast_stats, state) do
    # Broadcast network statistics to LiveView
    stats = calculate_current_stats(state)
    broadcast_network_update(:stats_update, stats)

    {:noreply, state}
  end

  # Private functions

  defp announce_presence do
    announce_activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "id" => "https://localhost:4001/activities/#{UUID.uuid4()}",
      "type" => "ThunderblockAnnounce",
      "actor" => "https://localhost:4001/api/federation/actor",
      "published" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "object" => %{
        "type" => "ThunderblockPresence",
        "name" => "New Thunderblock Online",
        "capabilities" => ["federation", "real_time", "data_collection", "ai_agents"]
      }
    }

    # Broadcast to any known instances (initially none)
    Federator.broadcast_activity(announce_activity)
  end

  defp perform_health_check_cycle(state) do
    Logger.debug("🩺 Performing network health check cycle...")

    # Check health of all known instances
    health_results =
      state.known_instances
      |> Enum.map(fn {domain, _instance} ->
        {domain, Instance.health_check(domain)}
      end)
      |> Map.new()

    # Calculate overall network health
    total_instances = map_size(state.known_instances)
    healthy_count =
      health_results
      |> Enum.count(fn {_domain, {status, health}} ->
        status == :ok && health == :online
      end)

    network_health = %{
      status: calculate_network_status(healthy_count, total_instances),
      last_check: DateTime.utc_now(),
      healthy_instances: healthy_count,
      total_instances: total_instances,
      health_percentage: if(total_instances > 0, do: healthy_count / total_instances * 100, else: 100)
    }

    # Broadcast health update
    broadcast_network_update(:health_update, network_health)

    %{state | network_health: network_health}
  end

  defp perform_discovery_cycle(state) do
    Logger.debug("🔍 Performing network discovery cycle...")

    # In a real implementation, this would query known instances for their peer lists
    # For now, we'll simulate discovery of some test instances
    test_instances = [
      "thunderblock-1.example.com",
      "thunderblock-2.example.com",
      "thunderblock-3.example.com"
    ]

    # Try to discover each test instance
    Enum.each(test_instances, fn domain ->
      unless Map.has_key?(state.known_instances, domain) do
        # Simulate successful discovery for demo purposes
        simulate_instance_discovery(domain)
      end
    end)

    %{state | last_discovery: DateTime.utc_now()}
  end

  defp simulate_instance_discovery(domain) do
    # Create a simulated instance for demo purposes
    now = DateTime.utc_now()

    simulated_instance = %Instance{
      domain: domain,
      actor_url: "https://#{domain}/api/federation/actor",
      name: "Simulated #{domain}",
      description: "A simulated Thunderblock instance for demo",
      version: "1.0.0",
      capabilities: ["federation", "real_time"],
      status: Enum.random([:online, :offline]),
      last_seen: now,
      created_at: now
    }

    # Register the simulated instance in ETS instead of syn
    # Check if the table exists first
    try do
      :ets.insert(:thundertab_instances, {domain, simulated_instance})
    rescue
      ArgumentError ->
        # Table doesn't exist, skip this insertion
        Logger.warning("ETS table :thundertab_instances not available, skipping instance registration")
    end

    # Add to our known instances
    GenServer.cast(__MODULE__, {:add_simulated_instance, domain, simulated_instance})
  end

  @impl true
  def handle_cast({:add_simulated_instance, domain, instance}, state) do
    new_known_instances = Map.put(state.known_instances, domain, instance)
    new_state = %{state | known_instances: new_known_instances}
    new_state = update_network_topology(new_state)

    broadcast_network_update(:instance_discovered, instance)

    {:noreply, new_state}
  end

  defp update_network_topology(state) do
    # Create topology graph for visualization
    nodes =
      [state.local_instance | Map.values(state.known_instances)]
      |> Enum.map(fn instance ->
        %{
          id: instance.domain,
          name: instance.name,
          status: instance.status,
          capabilities: instance.capabilities,
          x: :rand.uniform(800) + 100,
          y: :rand.uniform(600) + 100
        }
      end)

    # Create edges (connections between instances)
    edges =
      state.known_instances
      |> Enum.map(fn {domain, _instance} ->
        %{
          from: state.local_instance.domain,
          to: domain,
          status: :connected
        }
      end)

    topology_graph = %{nodes: nodes, edges: edges}

    %{state | topology_graph: topology_graph}
  end

  defp calculate_network_status(healthy_count, total_instances) do
    cond do
      total_instances == 0 -> :isolated
      healthy_count == 0 -> :all_down
      healthy_count == total_instances -> :all_healthy
      healthy_count / total_instances >= 0.8 -> :mostly_healthy
      healthy_count / total_instances >= 0.5 -> :degraded
      true -> :critical
    end
  end

  defp calculate_current_stats(state) do
    uptime_seconds = System.system_time(:second) - state.stats.uptime

    %{
      total_instances: map_size(state.known_instances) + 1, # +1 for local
      healthy_instances: Map.get(state.network_health, :healthy_instances, 0),
      network_health_percentage: Map.get(state.network_health, :health_percentage, 0),
      uptime_seconds: uptime_seconds,
      last_discovery: state.last_discovery,
      last_health_check: state.network_health.last_check
    }
  end

  defp broadcast_network_update(event_type, data) do
    Phoenix.PubSub.broadcast(
      Thundertab.PubSub,
      "federation:network",
      {event_type, data}
    )
  end
end
