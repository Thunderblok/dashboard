defmodule Thundertab.Federation.ActivityPub.WebFinger do
  @moduledoc """
  WebFinger implementation for Thunderblock instance discovery.

  Handles the WebFinger protocol (RFC 7033) for discovering Thunderblock
  instances across the federation network.
  """

  require Logger

  @doc """
  Setup WebFinger for a Thunderblock instance
  """
  def setup_webfinger(identity) do
    webfinger_data = %{
      "subject" => "acct:thunderblock@#{identity.domain}",
      "aliases" => [
        "https://#{identity.domain}/api/federation/actor",
        "https://#{identity.domain}/"
      ],
      "links" => [
        %{
          "rel" => "self",
          "type" => "application/activity+json",
          "href" => "https://#{identity.domain}/api/federation/actor"
        },
        %{
          "rel" => "http://webfinger.net/rel/profile-page",
          "type" => "text/html",
          "href" => "https://#{identity.domain}/"
        },
        %{
          "rel" => "http://schemas.google.com/g/2010#updates-from",
          "type" => "application/atom+xml",
          "href" => "https://#{identity.domain}/api/federation/feed"
        }
      ]
    }

    # Store WebFinger data for this instance in ETS
    :ets.insert(:thunderblock_webfinger, {identity.domain, webfinger_data})

    Logger.info("🔍 WebFinger setup complete for #{identity.domain}")
    {:ok, webfinger_data}
  end

  @doc """
  Discover a Thunderblock instance via WebFinger
  """
  def discover_instance(domain) do
    webfinger_url = "https://#{domain}/.well-known/webfinger?resource=acct:thunderblock@#{domain}"

    case Req.get(webfinger_url) do
      {:ok, %{status: 200, body: body}} ->
        Logger.info("🔍 Discovered Thunderblock instance: #{domain}")
        parse_webfinger_response(body, domain)

      {:error, reason} ->
        Logger.warn("❌ Failed to discover instance #{domain}: #{inspect(reason)}")
        {:error, :discovery_failed}
    end
  end

  @doc """
  Get WebFinger data for local instance
  """
  def get_local_webfinger(domain) do
    case :ets.lookup(:thunderblock_webfinger, domain) do
      [{^domain, webfinger_data}] ->
        {:ok, webfinger_data}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Resolve actor URL from WebFinger data
  """
  def resolve_actor_url(webfinger_data) do
    self_link =
      webfinger_data["links"]
      |> Enum.find(fn link ->
        link["rel"] == "self" && link["type"] == "application/activity+json"
      end)

    case self_link do
      %{"href" => actor_url} -> {:ok, actor_url}
      _ -> {:error, :no_actor_url}
    end
  end

  # Private functions

  defp parse_webfinger_response(body, domain) do
    try do
      parsed = Jason.decode!(body)

      # Validate it's a Thunderblock instance
      case validate_thunderblock_webfinger(parsed, domain) do
        :ok ->
          {:ok, parsed}

        {:error, reason} ->
          Logger.warn("⚠️  Invalid Thunderblock WebFinger for #{domain}: #{reason}")
          {:error, reason}
      end
    rescue
      Jason.DecodeError ->
        {:error, :invalid_json}
    end
  end

  defp validate_thunderblock_webfinger(webfinger_data, domain) do
    expected_subject = "acct:thunderblock@#{domain}"

    cond do
      webfinger_data["subject"] != expected_subject ->
        {:error, :invalid_subject}

      not has_self_link?(webfinger_data) ->
        {:error, :missing_self_link}

      true ->
        :ok
    end
  end

  defp has_self_link?(webfinger_data) do
    webfinger_data["links"]
    |> Enum.any?(fn link ->
      link["rel"] == "self" && link["type"] == "application/activity+json"
    end)
  end
end
