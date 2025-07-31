defmodule Thundertab.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize ETS tables for federation
    :ets.new(:thunderblock_instances, [:named_table, :public, :set])
    :ets.new(:thunderblock_identities, [:named_table, :public, :set])
    :ets.new(:thunderblock_webfinger, [:named_table, :public, :set])

    children = [
      ThundertabWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:thundertab, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Thundertab.PubSub},

      # Finch HTTP client for federation requests
      {Finch, name: Thundertab.Finch},

      # Federation Services
      {Thundertab.Federation.ActivityPub.Federator, []},
      {Thundertab.Federation.Thunderblock.Network,
        [local_instance: [domain: "localhost:4001", name: "Local Thunderblock"]]},      # Start to serve requests, typically the last entry
      ThundertabWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Thundertab.Supervisor]
    Supervisor.start_link(children, opts)
  end  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ThundertabWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
