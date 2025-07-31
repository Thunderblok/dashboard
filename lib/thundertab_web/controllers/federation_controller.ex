defmodule ThundertabWeb.FederationController do
  @moduledoc """
  ActivityPub Federation API endpoints for Thunderblock.

  Handles WebFinger, Actor, Inbox/Outbox, and other federation protocols.
  """

  use ThundertabWeb, :controller

  require Logger
  alias Thundertab.Federation.ActivityPub.{Adapter, WebFinger}
  alias Thundertab.Federation.Thunderblock.{Instance, Network, Identity}

  @doc """
  WebFinger endpoint for instance discovery
  """
  def webfinger(conn, %{"resource" => resource}) do
    case parse_webfinger_resource(resource) do
      {:ok, domain} ->
        case WebFinger.get_local_webfinger(domain) do
          {:ok, webfinger_data} ->
            conn
            |> put_resp_content_type("application/jrd+json")
            |> json(webfinger_data)

          {:error, :not_found} ->
            conn
            |> put_status(404)
            |> json(%{"error" => "Resource not found"})
        end

      {:error, :invalid_resource} ->
        conn
        |> put_status(400)
        |> json(%{"error" => "Invalid resource format"})
    end
  end

  @doc """
  Actor endpoint - returns ActivityPub actor document
  """
  def actor(conn, _params) do
    domain = get_request_domain(conn)

    case Instance.get_instance(domain) do
      {:ok, instance} ->
        actor_doc = Instance.generate_actor_document(instance)

        conn
        |> put_resp_content_type("application/activity+json")
        |> json(actor_doc)

      {:error, :not_found} ->
        # Create local instance if it doesn't exist
        case Instance.create_local_instance(domain: domain) do
          {:ok, instance} ->
            actor_doc = Instance.generate_actor_document(instance)

            conn
            |> put_resp_content_type("application/activity+json")
            |> json(actor_doc)

          error ->
            Logger.error("Failed to create local instance: #{inspect(error)}")

            conn
            |> put_status(500)
            |> json(%{"error" => "Internal server error"})
        end
    end
  end

  @doc """
  Inbox endpoint - receives ActivityPub messages
  """
  def inbox(conn, params) do
    Logger.info("📬 Received ActivityPub message: #{inspect(params)}")

    # Get sender domain from the activity
    sender_domain = extract_sender_domain(params)

    case Adapter.handle_incoming_activity(params, sender_domain) do
      {:ok, processed_activity} ->
        Logger.info("✅ Successfully processed activity from #{sender_domain}")

        conn
        |> put_status(202)
        |> json(%{"status" => "accepted"})

      {:error, reason} ->
        Logger.error("❌ Failed to process activity: #{inspect(reason)}")

        conn
        |> put_status(400)
        |> json(%{"error" => "Bad request"})
    end
  end

  @doc """
  Outbox endpoint - shows our recent activities
  """
  def outbox(conn, _params) do
    # In a real implementation, this would fetch recent activities from storage
    outbox_data = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "id" => "https://#{get_request_domain(conn)}/api/federation/outbox",
      "type" => "OrderedCollection",
      "totalItems" => 0,
      "orderedItems" => []
    }

    conn
    |> put_resp_content_type("application/activity+json")
    |> json(outbox_data)
  end

  @doc """
  Followers endpoint
  """
  def followers(conn, _params) do
    followers_data = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "id" => "https://#{get_request_domain(conn)}/api/federation/followers",
      "type" => "OrderedCollection",
      "totalItems" => 0,
      "orderedItems" => []
    }

    conn
    |> put_resp_content_type("application/activity+json")
    |> json(followers_data)
  end

  @doc """
  Following endpoint
  """
  def following(conn, _params) do
    # Get instances we're connected to
    known_instances = Network.get_known_instances()

    following_items =
      known_instances
      |> Enum.map(fn instance -> instance.actor_url end)

    following_data = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "id" => "https://#{get_request_domain(conn)}/api/federation/following",
      "type" => "OrderedCollection",
      "totalItems" => length(following_items),
      "orderedItems" => following_items
    }

    conn
    |> put_resp_content_type("application/activity+json")
    |> json(following_data)
  end

  @doc """
  Health check endpoint
  """
  def health(conn, _params) do
    network_health = Network.get_network_health()
    network_stats = Network.get_network_stats()

    health_data = %{
      "status" => "healthy",
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "version" => "1.0.0",
      "network" => %{
        "total_instances" => network_stats.total_instances,
        "healthy_instances" => network_stats.healthy_instances,
        "health_percentage" => network_stats.network_health_percentage
      },
      "capabilities" => [
        "federation",
        "real_time",
        "data_collection",
        "activity_pub",
        "webfinger"
      ]
    }

    conn
    |> json(health_data)
  end

  @doc """
  Atom/RSS feed endpoint
  """
  def feed(conn, _params) do
    # Simple Atom feed for compatibility
    atom_feed = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>Thunderblock Instance</title>
      <link href="https://#{get_request_domain(conn)}/" />
      <updated>#{DateTime.utc_now() |> DateTime.to_iso8601()}</updated>
      <id>https://#{get_request_domain(conn)}/api/federation/feed</id>
      <subtitle>A Thunderblock federation node</subtitle>
    </feed>
    """

    conn
    |> put_resp_content_type("application/atom+xml")
    |> send_resp(200, atom_feed)
  end

  # Private helper functions

  defp parse_webfinger_resource(resource) do
    case String.split(resource, "@") do
      ["acct:thunderblock", domain] -> {:ok, domain}
      _ -> {:error, :invalid_resource}
    end
  end

  defp get_request_domain(conn) do
    # Extract domain from request host
    case get_req_header(conn, "host") do
      [host] -> host
      _ -> "localhost:4001"
    end
  end

  defp extract_sender_domain(activity) do
    case activity["actor"] do
      actor_url when is_binary(actor_url) ->
        URI.parse(actor_url).host

      _ ->
        "unknown"
    end
  end
end
