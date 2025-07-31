defmodule Thundertab.Federation.ActivityPub.Adapter do
  @moduledoc """
  Thunderblock-specific ActivityPub adapter for federation.

  Clean-room implementation inspired by Bonfire patterns but designed
  specifically for Thunderblock-to-Thunderblock networking.
  """

  require Logger
  alias Thundertab.Federation.ActivityPub.{WebFinger, Federator}
  alias Thundertab.Federation.Thunderblock.{Instance, Identity}

  @doc """
  Initialize federation for a Thunderblock instance
  """
  def initialize_instance(instance_config) do
    with {:ok, identity} <- Identity.create_instance_identity(instance_config),
         {:ok, _keys} <- generate_keypair_for_instance(identity),
         {:ok, _webfinger} <- WebFinger.setup_webfinger(identity) do
      Logger.info("✅ Thunderblock federation initialized for #{identity.domain}")
      {:ok, identity}
    else
      error ->
        Logger.error("❌ Failed to initialize Thunderblock federation: #{inspect(error)}")
        error
    end
  end

  @doc """
  Send ActivityPub message to another Thunderblock
  """
  def send_activity(from_instance, to_instance, activity) do
    with {:ok, signed_activity} <- sign_activity(from_instance, activity),
         {:ok, response} <- deliver_activity(to_instance, signed_activity) do
      Logger.info("🚀 Activity delivered to #{to_instance.domain}")
      {:ok, response}
    else
      error ->
        Logger.error("❌ Failed to deliver activity: #{inspect(error)}")
        error
    end
  end

  @doc """
  Handle incoming ActivityPub message
  """
  def handle_incoming_activity(activity, from_domain) do
    with {:ok, verified_activity} <- verify_activity_signature(activity, from_domain),
         {:ok, processed} <- process_thunderblock_activity(verified_activity) do
      # Broadcast to LiveView for real-time updates
      Phoenix.PubSub.broadcast(
        Thundertab.PubSub,
        "federation:activities",
        {:new_activity, processed}
      )

      {:ok, processed}
    else
      error ->
        Logger.error("❌ Failed to process incoming activity: #{inspect(error)}")
        error
    end
  end

  # Private functions

  defp generate_keypair_for_instance(identity) do
    keypair = JOSE.JWS.generate_key(%{"alg" => "RS256"})
    # Store keypair securely (in production, use proper key storage)
    {:ok, keypair}
  end

  defp sign_activity(instance, activity) do
    # Sign activity with instance's private key
    # This is a simplified version - production needs proper HTTP signatures
    signed_activity = Map.put(activity, "signature", "signed_by_#{instance.domain}")
    {:ok, signed_activity}
  end

  defp deliver_activity(to_instance, activity) do
    url = "https://#{to_instance.domain}/api/federation/inbox"

    Req.post(url,
      json: activity,
      headers: [
        {"content-type", "application/activity+json"},
        {"user-agent", "Thunderblock/1.0"}
      ]
    )
  end

  defp verify_activity_signature(activity, _from_domain) do
    # Simplified verification - production needs proper signature verification
    {:ok, activity}
  end

  defp process_thunderblock_activity(activity) do
    case activity["type"] do
      "ThunderblockAnnounce" ->
        process_thunderblock_announce(activity)

      "ThunderblockConnect" ->
        process_thunderblock_connect(activity)

      "ThunderblockHealthCheck" ->
        process_thunderblock_health_check(activity)

      _ ->
        Logger.warn("Unknown Thunderblock activity type: #{activity["type"]}")
        {:ok, activity}
    end
  end

  defp process_thunderblock_announce(activity) do
    Logger.info("📢 Thunderblock announce from #{activity["actor"]}")
    {:ok, activity}
  end

  defp process_thunderblock_connect(activity) do
    Logger.info("🔗 Thunderblock connection request from #{activity["actor"]}")
    {:ok, activity}
  end

  defp process_thunderblock_health_check(activity) do
    Logger.info("💓 Thunderblock health check from #{activity["actor"]}")
    {:ok, activity}
  end
end
