defmodule Thundertab.Federation.ActivityPub.Federator do
  @moduledoc """
  Federation message routing and delivery system for Thunderblocks.

  Handles queuing, routing, and delivery of ActivityPub messages
  between Thunderblock instances.
  """

  use GenServer
  require Logger

  alias Thundertab.Federation.ActivityPub.{Adapter, WebFinger}
  alias Thundertab.Federation.Thunderblock.{Instance, Network}

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Queue an activity for federation delivery
  """
  def federate_activity(activity, target_instances \\ :all) do
    GenServer.cast(__MODULE__, {:federate_activity, activity, target_instances})
  end

  @doc """
  Send direct message to specific Thunderblock
  """
  def send_to_thunderblock(target_domain, activity) do
    GenServer.call(__MODULE__, {:send_to_thunderblock, target_domain, activity})
  end

  @doc """
  Broadcast activity to all known Thunderblocks
  """
  def broadcast_activity(activity) do
    GenServer.cast(__MODULE__, {:broadcast_activity, activity})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    Logger.info("🚀 Thunderblock Federator starting...")

    state = %{
      pending_deliveries: :queue.new(),
      delivery_workers: 0,
      max_workers: Keyword.get(opts, :max_workers, 10),
      retry_attempts: Keyword.get(opts, :retry_attempts, 3)
    }

    # Schedule periodic health checks
    :timer.send_interval(30_000, :health_check_broadcast)

    {:ok, state}
  end

  @impl true
  def handle_call({:send_to_thunderblock, target_domain, activity}, _from, state) do
    case deliver_to_thunderblock(target_domain, activity) do
      {:ok, result} ->
        {:reply, {:ok, result}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast({:federate_activity, activity, target_instances}, state) do
    targets = resolve_target_instances(target_instances)

    Enum.each(targets, fn domain ->
      delivery = %{
        activity: activity,
        target: domain,
        attempts: 0,
        queued_at: System.system_time(:second)
      }

      state = enqueue_delivery(delivery, state)
    end)

    state = process_delivery_queue(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:broadcast_activity, activity}, state) do
    # Get all known Thunderblock instances
    known_instances = Network.get_known_instances()

    Enum.each(known_instances, fn instance ->
      federate_activity(activity, [instance.domain])
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(:health_check_broadcast, state) do
    # Broadcast health check to all known instances
    health_activity = create_health_check_activity()
    broadcast_activity(health_activity)

    {:noreply, state}
  end

  @impl true
  def handle_info({:delivery_complete, delivery, result}, state) do
    case result do
      :ok ->
        Logger.info("✅ Successfully delivered to #{delivery.target}")

      {:error, reason} ->
        Logger.warn("❌ Failed delivery to #{delivery.target}: #{inspect(reason)}")

        # Retry if attempts < max_attempts
        if delivery.attempts < state.retry_attempts do
          retry_delivery = %{delivery | attempts: delivery.attempts + 1}
          state = enqueue_delivery(retry_delivery, state)
        end
    end

    state = %{state | delivery_workers: state.delivery_workers - 1}
    state = process_delivery_queue(state)

    {:noreply, state}
  end

  # Private functions

  defp resolve_target_instances(:all) do
    Network.get_known_instances()
    |> Enum.map(& &1.domain)
  end

  defp resolve_target_instances(domains) when is_list(domains) do
    domains
  end

  defp enqueue_delivery(delivery, state) do
    new_queue = :queue.in(delivery, state.pending_deliveries)
    %{state | pending_deliveries: new_queue}
  end

  defp process_delivery_queue(state) do
    cond do
      state.delivery_workers >= state.max_workers ->
        state

      :queue.is_empty(state.pending_deliveries) ->
        state

      true ->
        {{:value, delivery}, new_queue} = :queue.out(state.pending_deliveries)

        # Start async delivery
        task = Task.async(fn ->
          result = deliver_to_thunderblock(delivery.target, delivery.activity)
          send(self(), {:delivery_complete, delivery, result})
        end)

        new_state = %{
          state |
          pending_deliveries: new_queue,
          delivery_workers: state.delivery_workers + 1
        }

        process_delivery_queue(new_state)
    end
  end

  defp deliver_to_thunderblock(target_domain, activity) do
    with {:ok, webfinger} <- WebFinger.discover_instance(target_domain),
         {:ok, actor_url} <- WebFinger.resolve_actor_url(webfinger),
         {:ok, instance} <- Instance.from_actor_url(actor_url) do

      Adapter.send_activity(get_local_instance(), instance, activity)
    else
      error ->
        Logger.error("Failed to deliver to #{target_domain}: #{inspect(error)}")
        error
    end
  end

  defp get_local_instance do
    # Get local instance info - in production this would come from config
    %{
      domain: "localhost:4001",
      actor_url: "https://localhost:4001/api/federation/actor"
    }
  end

  defp create_health_check_activity do
    %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "id" => "https://#{get_local_instance().domain}/activities/#{UUID.uuid4()}",
      "type" => "ThunderblockHealthCheck",
      "actor" => get_local_instance().actor_url,
      "published" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "object" => %{
        "type" => "ThunderblockStatus",
        "status" => "healthy",
        "version" => "1.0.0",
        "capabilities" => ["federation", "real_time", "data_collection"]
      }
    }
  end
end
