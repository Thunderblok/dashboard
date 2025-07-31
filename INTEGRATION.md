# 🔗 Thunderprism Dashboard Integration Guide

This guide shows how to integrate the **Thunderprism Real-Time Federation Dashboard** into the main [Thunderblok/Landing](https://github.com/Thunderblok/Landing) project.

## 🚀 Quick Integration Options

### Option 1: Embedded Dashboard (Recommended)
Embed the dashboard directly into your Next.js landing page using an iframe or component wrapper:

```jsx
// components/Dashboard.tsx
export default function Dashboard() {
  return (
    <div className="w-full h-screen border-0">
      <iframe 
        src="http://localhost:4000/federation/dashboard"
        className="w-full h-full border-0 rounded-lg"
        title="Thunderprism Federation Dashboard"
      />
    </div>
  )
}
```

### Option 2: Standalone Deployment
Deploy the Phoenix app separately and link to it from your landing page:

```bash
# Clone and setup
git clone https://github.com/Thunderblok/dashboard.git
cd dashboard
mix deps.get
cd assets && npm install && cd ..

# Start the server
mix phx.server
# Visit: http://localhost:4000/federation/dashboard
```

### Option 3: Docker Integration
Add to your `docker-compose.yml`:

```yaml
services:
  thunderprism:
    build: ./dashboard
    ports:
      - "4000:4000"
    environment:
      - MIX_ENV=prod
      - SECRET_KEY_BASE=your-secret-key
```

## 🎨 Matching Design System

The dashboard uses the same neon color palette as your landing page:

```css
/* Shared neon colors */
--neon-cyan: #00ffff
--neon-magenta: #ff00ff  
--neon-purple: #8a2be2
--neon-electric: #39ff14
```

## 🔌 API Integration

Connect the dashboard to your existing data sources:

```elixir
# lib/thundertab/federation/data_source.ex
defmodule Thundertab.Federation.DataSource do
  # Replace with your actual data endpoints
  def fetch_instances do
    # Connect to your instance database
    HTTPoison.get("https://your-api.com/instances")
  end
  
  def fetch_activities do
    # Connect to your activity feed
    HTTPoison.get("https://your-api.com/activities")
  end
end
```

## 🌐 Network Configuration

Update federation settings in `config/config.exs`:

```elixir
config :thundertab, :federation,
  domain: "your-domain.com",
  webfinger_url: "https://your-domain.com/.well-known/webfinger",
  nodeinfo_url: "https://your-domain.com/.well-known/nodeinfo"
```

## 🔄 Real-Time Synchronization

The dashboard publishes events that your Next.js app can subscribe to:

```typescript
// Subscribe to dashboard events
const eventSource = new EventSource('http://localhost:4000/api/events');
eventSource.onmessage = (event) => {
  const data = JSON.parse(event.data);
  // Update your landing page with real-time data
  updateLandingPageMetrics(data);
};
```

## 📊 Metrics Export

Export dashboard metrics to your analytics:

```elixir
# Add to your Phoenix channels
def handle_in("export_metrics", _params, socket) do
  metrics = Thundertab.Metrics.get_current()
  {:reply, {:ok, metrics}, socket}
end
```

## 🚢 Production Deployment

### Environment Variables
```bash
export SECRET_KEY_BASE=$(mix phx.gen.secret)
export DATABASE_URL="postgresql://user:pass@localhost/thundertab_prod"
export PHX_HOST="dashboard.your-domain.com"
export PORT=4000
```

### Nginx Configuration
```nginx
upstream thunderprism {
    server 127.0.0.1:4000;
}

server {
    listen 443 ssl;
    server_name dashboard.your-domain.com;
    
    location / {
        proxy_pass http://thunderprism;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## 🎯 Landing Page Integration

Add a dashboard section to your landing page:

```jsx
// pages/index.tsx
import Dashboard from '../components/Dashboard'

export default function Home() {
  return (
    <main>
      {/* Your existing landing content */}
      
      <section className="py-20 bg-gradient-to-b from-gray-900 to-black">
        <div className="container mx-auto px-4">
          <h2 className="text-4xl font-bold text-center mb-12 bg-gradient-to-r from-cyan-400 to-purple-400 bg-clip-text text-transparent">
            🌐 Live Federation Network
          </h2>
          <Dashboard />
        </div>
      </section>
    </main>
  )
}
```

## 🔐 Security Configuration

For production integration:

```elixir
# config/prod.exs
config :thundertab, ThundertabWeb.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  check_origin: ["https://your-domain.com", "https://dashboard.your-domain.com"]
```

## 📈 Analytics Integration

Track dashboard usage:

```typescript
// Track dashboard interactions
useEffect(() => {
  // Google Analytics
  gtag('event', 'dashboard_view', {
    event_category: 'engagement',
    event_label: 'federation_dashboard'
  });
  
  // PostHog
  posthog.capture('dashboard_viewed', {
    source: 'landing_page'
  });
}, []);
```

## 🤝 Need Help?

- 📖 **Full Documentation**: Check the main [README.md](./README.md)
- 🐛 **Issues**: [Create an issue](https://github.com/Thunderblok/dashboard/issues)
- 💬 **Questions**: [Start a discussion](https://github.com/Thunderblok/dashboard/discussions)

---

**Ready to power up your federation monitoring! ⚡**
