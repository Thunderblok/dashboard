defmodule Thundertab.Federation.Thunderblock.Instance do
  @moduledoc """
  Thunderblock instance management and identity handling.

  Manages the identity and metadata of Thunderblock instances
  in the federation network.
  """

  require Logger

  defstruct [
    :domain,
    :actor_url,
    :public_key,
    :name,
    :description,
    :version,
    :capabilities,
    :status,
    :last_seen,
    :created_at
  ]

  @type t :: %__MODULE__{
    domain: String.t(),
    actor_url: String.t(),
    public_key: String.t(),
    name: String.t(),
    description: String.t(),
    version: String.t(),
    capabilities: [String.t()],
    status: :online | :offline | :unknown,
    last_seen: DateTime.t(),
    created_at: DateTime.t()
  }

  @doc """
  Create a new Thunderblock instance from actor data
  """
  def from_actor_url(actor_url) do
    case fetch_actor_data(actor_url) do
      {:ok, actor_data} ->
        parse_actor_data(actor_data)

      error ->
        error
    end
  end

  @doc """
  Create local instance identity
  """
  def create_local_instance(config) do
    now = DateTime.utc_now()

    instance = %__MODULE__{
      domain: config[:domain] || "localhost:4001",
      actor_url: "https://#{config[:domain] || "localhost:4001"}/api/federation/actor",
      name: config[:name] || "Thunderblock Instance",
      description: config[:description] || "A Thunderblock federation node",
      version: "1.0.0",
      capabilities: ["federation", "real_time", "data_collection", "ai_agents"],
      status: :online,
      last_seen: now,
      created_at: now
    }

    # Register instance globally in ETS
    :ets.insert(:thunderblock_instances, {instance.domain, instance})

    Logger.info("🏗️ Created local Thunderblock instance: #{instance.domain}")
    {:ok, instance}
  end

  @doc """
  Update instance status and last seen
  """
  def update_status(domain, status) do
    case :ets.lookup(:thunderblock_instances, domain) do
      [{^domain, instance}] ->
        updated_instance = %{instance |
          status: status,
          last_seen: DateTime.utc_now()
        }

        :ets.insert(:thunderblock_instances, {domain, updated_instance})

        # Broadcast status change
        Phoenix.PubSub.broadcast(
          Thundertab.PubSub,
          "federation:instances",
          {:instance_status_changed, updated_instance}
        )

        {:ok, updated_instance}

      [] ->
        {:error, :instance_not_found}
    end
  end

  @doc """
  Get instance by domain
  """
  def get_instance(domain) do
    case :ets.lookup(:thunderblock_instances, domain) do
      [{^domain, instance}] -> {:ok, instance}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  List all known instances
  """
  def list_instances do
    :ets.tab2list(:thunderblock_instances)
    |> Enum.map(fn {_domain, instance} -> instance end)
  end

  @doc """
  Check if instance is healthy
  """
  def health_check(domain) do
    with {:ok, instance} <- get_instance(domain),
         {:ok, response} <- ping_instance(instance) do

      # Update status based on response
      status = if response.status == 200, do: :online, else: :offline
      update_status(domain, status)

      {:ok, status}
    else
      _ ->
        update_status(domain, :offline)
        {:ok, :offline}
    end
  end

  @doc """
  Generate actor document for local instance
  """
  def generate_actor_document(instance) do
    %{
      "@context" => [
        "https://www.w3.org/ns/activitystreams",
        "https://w3id.org/security/v1"
      ],
      "id" => instance.actor_url,
      "type" => "Service",
      "preferredUsername" => "thunderblock",
      "name" => instance.name,
      "summary" => instance.description,
      "url" => "https://#{instance.domain}/",
      "inbox" => "https://#{instance.domain}/api/federation/inbox",
      "outbox" => "https://#{instance.domain}/api/federation/outbox",
      "followers" => "https://#{instance.domain}/api/federation/followers",
      "following" => "https://#{instance.domain}/api/federation/following",
      "publicKey" => %{
        "id" => "#{instance.actor_url}#main-key",
        "owner" => instance.actor_url,
        "publicKeyPem" => instance.public_key || generate_placeholder_key()
      },
      "capabilities" => instance.capabilities,
      "version" => instance.version,
      "endpoints" => %{
        "sharedInbox" => "https://#{instance.domain}/api/federation/inbox"
      }
    }
  end

  # Private functions

  defp fetch_actor_data(actor_url) do
    Req.get(actor_url, headers: [{"accept", "application/activity+json"}])
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:error, reason} ->
        {:error, {:fetch_failed, reason}}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}
    end
  end

  defp parse_actor_data(actor_data) do
    try do
      now = DateTime.utc_now()

      instance = %__MODULE__{
        domain: extract_domain_from_id(actor_data["id"]),
        actor_url: actor_data["id"],
        public_key: get_in(actor_data, ["publicKey", "publicKeyPem"]),
        name: actor_data["name"] || "Unknown Thunderblock",
        description: actor_data["summary"] || "",
        version: actor_data["version"] || "unknown",
        capabilities: actor_data["capabilities"] || [],
        status: :online,
        last_seen: now,
        created_at: now
      }

      # Register discovered instance
      :ets.insert(:thunderblock_instances, {instance.domain, instance})

      {:ok, instance}
    rescue
      error ->
        Logger.error("Failed to parse actor data: #{inspect(error)}")
        {:error, :invalid_actor_data}
    end
  end

  defp extract_domain_from_id(actor_id) do
    URI.parse(actor_id).host
  end

  defp ping_instance(instance) do
    health_url = "https://#{instance.domain}/api/federation/health"

    Req.get(health_url,
      receive_timeout: 5_000,
      headers: [{"user-agent", "Thunderblock/1.0"}]
    )
  end

  defp generate_placeholder_key do
    # In production, this should be a real RSA public key
    "-----BEGIN PUBLIC KEY-----\nPlaceholderKey\n-----END PUBLIC KEY-----"
  end
end
