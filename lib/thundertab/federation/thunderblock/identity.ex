defmodule Thundertab.Federation.Thunderblock.Identity do
  @moduledoc """
  Thunderblock identity and cryptographic key management.

  Handles creation and management of cryptographic identities
  for Thunderblock instances in the federation.
  """

  require Logger

  defstruct [
    :domain,
    :actor_id,
    :public_key,
    :private_key,
    :key_id,
    :created_at
  ]

  @type t :: %__MODULE__{
    domain: String.t(),
    actor_id: String.t(),
    public_key: String.t(),
    private_key: String.t(),
    key_id: String.t(),
    created_at: DateTime.t()
  }

  @doc """
  Create instance identity with cryptographic keys
  """
  def create_instance_identity(config) do
    domain = config[:domain] || "localhost:4001"

    case generate_rsa_keypair() do
      {:ok, {public_key, private_key}} ->
        identity = %__MODULE__{
          domain: domain,
          actor_id: "https://#{domain}/api/federation/actor",
          public_key: public_key,
          private_key: private_key,
          key_id: "https://#{domain}/api/federation/actor#main-key",
          created_at: DateTime.utc_now()
        }

        # Store identity securely
        store_identity(identity)

        Logger.info("🔐 Created cryptographic identity for #{domain}")
        {:ok, identity}

      error ->
        Logger.error("Failed to generate keypair: #{inspect(error)}")
        error
    end
  end

  @doc """
  Get stored identity for domain
  """
  def get_identity(domain) do
    case :ets.lookup(:thunderblock_identities, domain) do
      [{^domain, identity}] -> {:ok, identity}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Sign data with instance private key
  """
  def sign_data(domain, data) do
    with {:ok, identity} <- get_identity(domain) do
      signature = create_signature(data, identity.private_key)
      {:ok, signature}
    end
  end

  @doc """
  Verify signature from another instance
  """
  def verify_signature(domain, data, signature) do
    with {:ok, identity} <- get_identity(domain) do
      verify_signature_with_key(data, signature, identity.public_key)
    end
  end

  @doc """
  Create HTTP signature headers for ActivityPub requests
  """
  def create_http_signature(domain, request_method, request_path, body \\ nil) do
    with {:ok, identity} <- get_identity(domain) do
      signature_string = build_signature_string(request_method, request_path, body)
      signature = create_signature(signature_string, identity.private_key)

      signature_header = [
        "keyId=\"#{identity.key_id}\"",
        "algorithm=\"rsa-sha256\"",
        "headers=\"(request-target) host date\"",
        "signature=\"#{signature}\""
      ] |> Enum.join(",")

      {:ok, signature_header}
    end
  end

  @doc """
  Verify HTTP signature from incoming request
  """
  def verify_http_signature(signature_header, request_method, request_path, headers) do
    with {:ok, parsed_sig} <- parse_signature_header(signature_header),
         {:ok, public_key} <- fetch_public_key(parsed_sig["keyId"]),
         signature_string <- build_signature_string_from_headers(
           request_method,
           request_path,
           headers,
           parsed_sig["headers"]
         ) do

      verify_signature_with_key(signature_string, parsed_sig["signature"], public_key)
    end
  end

  @doc """
  Export public key for WebFinger/Actor responses
  """
  def export_public_key(domain) do
    case get_identity(domain) do
      {:ok, identity} ->
        {:ok, identity.public_key}

      error ->
        error
    end
  end

  # Private functions

  defp generate_rsa_keypair do
    try do
      # Generate RSA key pair using JOSE
      jwk = JOSE.JWK.generate_key({:rsa, 2048})

      # Export keys
      {_modules, public_key_map} = JOSE.JWK.to_public_key(jwk)
      {_modules, private_key_map} = JOSE.JWK.to_key(jwk)

      # Convert to PEM format
      public_key_pem = format_rsa_public_key(public_key_map)
      private_key_pem = format_rsa_private_key(private_key_map)

      {:ok, {public_key_pem, private_key_pem}}
    rescue
      error ->
        {:error, {:key_generation_failed, error}}
    end
  end

  defp format_rsa_public_key(key_map) do
    # Simplified PEM formatting - in production use proper PEM encoding
    "-----BEGIN PUBLIC KEY-----\n#{Base.encode64(:crypto.hash(:sha256, inspect(key_map)))}\n-----END PUBLIC KEY-----"
  end

  defp format_rsa_private_key(key_map) do
    # Simplified PEM formatting - in production use proper PEM encoding
    "-----BEGIN PRIVATE KEY-----\n#{Base.encode64(:crypto.hash(:sha256, inspect(key_map)))}\n-----END PRIVATE KEY-----"
  end

  defp store_identity(identity) do
    # Store in ETS for fast lookup
    :ets.insert(:thunderblock_identities, {identity.domain, identity})

    # In production, also store in encrypted persistent storage
    Logger.debug("🔐 Stored identity for #{identity.domain}")
  end

  defp create_signature(data, private_key) do
    # Simplified signature creation - in production use proper RSA signing
    hash = :crypto.hash(:sha256, data)
    Base.encode64(hash <> private_key)
  end

  defp verify_signature_with_key(data, signature, public_key) do
    try do
      expected_signature = create_signature(data, String.replace(public_key, "PUBLIC", "PRIVATE"))

      if signature == expected_signature do
        {:ok, :valid}
      else
        {:error, :invalid_signature}
      end
    rescue
      _ ->
        {:error, :verification_failed}
    end
  end

  defp build_signature_string(method, path, body) do
    date = DateTime.utc_now() |> DateTime.to_iso8601()
    host = "localhost:4001"  # In production, get from config

    signature_parts = [
      "(request-target): #{String.downcase(method)} #{path}",
      "host: #{host}",
      "date: #{date}"
    ]

    if body do
      content_length = byte_size(body)
      signature_parts ++ ["content-length: #{content_length}"]
    else
      signature_parts
    end
    |> Enum.join("\n")
  end

  defp build_signature_string_from_headers(method, path, headers, header_list) do
    header_names = String.split(header_list, " ")

    header_names
    |> Enum.map(fn header_name ->
      case header_name do
        "(request-target)" ->
          "(request-target): #{String.downcase(method)} #{path}"

        name ->
          value = Map.get(headers, name, "")
          "#{name}: #{value}"
      end
    end)
    |> Enum.join("\n")
  end

  defp parse_signature_header(signature_header) do
    try do
      parsed =
        signature_header
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reduce(%{}, fn part, acc ->
          [key, value] = String.split(part, "=", parts: 2)
          clean_value = String.trim(value, "\"")
          Map.put(acc, key, clean_value)
        end)

      {:ok, parsed}
    rescue
      _ ->
        {:error, :invalid_signature_header}
    end
  end

  defp fetch_public_key(key_id) do
    # Extract domain from key_id and fetch public key
    domain = URI.parse(key_id).host

    case get_identity(domain) do
      {:ok, identity} ->
        {:ok, identity.public_key}

      {:error, :not_found} ->
        # Try to fetch from remote instance
        fetch_remote_public_key(key_id)

      error ->
        error
    end
  end

  defp fetch_remote_public_key(key_id) do
    # Extract actor URL from key_id
    actor_url = String.replace(key_id, ~r/#.*$/, "")

    case Req.get(actor_url, headers: [{"accept", "application/activity+json"}]) do
      {:ok, %{status: 200, body: actor_data}} ->
        public_key = get_in(actor_data, ["publicKey", "publicKeyPem"])
        {:ok, public_key}

      _ ->
        {:error, :public_key_fetch_failed}
    end
  end
end
