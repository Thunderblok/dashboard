# ⚡ Thunderprism Dashboard

**Real-time federation control interface built with Phoenix LiveView + Neon UI**

A next-generation dashboard for managing Thunderblock federation networks with live metrics, activity feeds, and network visualization.

## 🌟 Features

- **Real-time Federation Monitoring** - Live network topology and health metrics
- **Neon UI Theme** - Electric cyan, magenta, purple, and orange color palette  
- **Resource Usage Tracking** - CPU, Memory, Network with animated progress bars
- **Activity Feed** - Live event stream with timestamps
- **Instance Discovery** - Scan and connect to federation nodes
- **WebSocket Live Updates** - Server-push updates every 2 seconds
- **BEAM-Native Performance** - Built on Elixir/Phoenix for reliability

## 🎨 Design

- **Geometric Logo** with animated SVG stroke paths
- **Grid Sweep Animations** with neon particle effects
- **Glassmorphism Cards** with backdrop blur
- **Professional Typography** using Inter font
- **Mobile Responsive** design

## 🚀 Tech Stack

- **Phoenix LiveView** - Server-side rendered real-time UI
- **Tailwind CSS v3** - Custom neon utilities and animations
- **DaisyUI** - Component foundation
- **PubSub** - Real-time broadcasting (node:stats, activity:feed)
- **ETS** - In-memory state management
- **SVG Animations** - Pure CSS stroke-dashoffset effects

## 🛠️ Quick Start

```bash
# Install dependencies
mix deps.get
cd assets && npm install

# Start the server
mix phx.server
```

Visit `http://localhost:4001` to see the dashboard.

## 📡 Federation Protocol

Built for Thunderblock federation networks with:

- **ActivityPub** compatibility
- **WebFinger** discovery
- **Real-time health checks**
- **Network topology mapping**
- **Instance capability detection**

## 🌐 Integration

This dashboard can be integrated into existing web applications as:

- **Standalone Phoenix app** (current setup)
- **Embedded iframe** widget
- **API backend** with frontend of choice
- **Docker container** for microservices

## 🎯 Perfect For

- **Company landing pages** with live federation status
- **User-hosted nodes** for personal federation management  
- **Network monitoring** and diagnostics
- **Demo environments** showing real-time capabilities

---

**Built with ⚡ by the Thunderblock team**

*"Intelligence, distributed. Autonomy, embodied."*
