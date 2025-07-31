defmodule ThundertabWeb.Router do
  use ThundertabWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ThundertabWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :federation_api do
    plug :accepts, ["json", "application/activity+json", "application/ld+json"]
  end

  # Main application routes
  scope "/", ThundertabWeb do
    pipe_through :browser

    # Federation Dashboard as homepage
    live "/", Live.Federation.DashboardLive, :index

    # Original home page moved
    get "/welcome", PageController, :home
  end

  # Federation API endpoints
  scope "/api/federation", ThundertabWeb do
    pipe_through :federation_api

    # Actor endpoint
    get "/actor", FederationController, :actor

    # Inbox for incoming ActivityPub messages
    post "/inbox", FederationController, :inbox

    # Outbox for our activities
    get "/outbox", FederationController, :outbox

    # Followers/Following
    get "/followers", FederationController, :followers
    get "/following", FederationController, :following

    # Health check endpoint
    get "/health", FederationController, :health

    # Feed endpoint
    get "/feed", FederationController, :feed
  end

  # WebFinger endpoint
  scope "/.well-known", ThundertabWeb do
    pipe_through :federation_api

    get "/webfinger", FederationController, :webfinger
  end

  # Development routes
  if Application.compile_env(:thundertab, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
