export default {
  mounted() {
    console.log("🌐 Network Visualization mounted!");
    
    // Initialize canvas
    this.canvas = document.createElement('canvas');
    this.canvas.width = this.el.clientWidth;
    this.canvas.height = this.el.clientHeight;
    this.canvas.style.position = 'absolute';
    this.canvas.style.top = '0';
    this.canvas.style.left = '0';
    this.el.appendChild(this.canvas);
    
    this.ctx = this.canvas.getContext('2d');
    
    // Network state
    this.nodes = [];
    this.edges = [];
    this.animationId = null;
    
    // Animation state
    this.pulseTime = 0;
    this.particles = [];
    
    // Start animation loop
    this.startAnimation();
    
    // Handle resize
    this.resizeObserver = new ResizeObserver(() => {
      this.canvas.width = this.el.clientWidth;
      this.canvas.height = this.el.clientHeight;
    });
    this.resizeObserver.observe(this.el);
  },
  
  destroyed() {
    if (this.animationId) {
      cancelAnimationFrame(this.animationId);
    }
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
    }
  },
  
  // Handle events from LiveView
  handleEvent(event, payload) {
    switch(event) {
      case "update-topology":
        this.updateTopology(payload.topology);
        break;
      case "instance-discovered":
        this.addInstance(payload.instance);
        break;
      case "new-activity":
        this.addActivityPulse(payload.activity);
        break;
    }
  },
  
  updateTopology(topology) {
    console.log("🔄 Updating network topology:", topology);
    this.nodes = topology.nodes || [];
    this.edges = topology.edges || [];
    
    // Position nodes if they don't have positions
    this.layoutNodes();
  },
  
  addInstance(instance) {
    console.log("✨ Adding new instance:", instance);
    
    const node = {
      id: instance.domain,
      name: instance.name,
      status: instance.status,
      capabilities: instance.capabilities,
      x: Math.random() * (this.canvas.width - 200) + 100,
      y: Math.random() * (this.canvas.height - 200) + 100,
      isNew: true
    };
    
    this.nodes.push(node);
    
    // Add connection to local instance
    const localNode = this.nodes.find(n => n.id.includes('localhost'));
    if (localNode) {
      this.edges.push({
        from: localNode.id,
        to: node.id,
        status: 'connected'
      });
    }
    
    // Animate the new node
    setTimeout(() => {
      node.isNew = false;
    }, 2000);
  },
  
  addActivityPulse(activity) {
    console.log("💫 Adding activity pulse:", activity);
    
    // Create pulse particles along network edges
    this.edges.forEach(edge => {
      const fromNode = this.nodes.find(n => n.id === edge.from);
      const toNode = this.nodes.find(n => n.id === edge.to);
      
      if (fromNode && toNode) {
        this.particles.push({
          x: fromNode.x,
          y: fromNode.y,
          targetX: toNode.x,
          targetY: toNode.y,
          progress: 0,
          life: 100,
          maxLife: 100,
          color: this.getActivityColor(activity.type)
        });
      }
    });
  },
  
  layoutNodes() {
    if (this.nodes.length === 0) return;
    
    const centerX = this.canvas.width / 2;
    const centerY = this.canvas.height / 2;
    const radius = Math.min(centerX, centerY) * 0.6;
    
    // Place local instance at center
    const localNode = this.nodes.find(n => n.id.includes('localhost'));
    if (localNode) {
      localNode.x = centerX;
      localNode.y = centerY;
    }
    
    // Arrange other nodes in a circle
    const otherNodes = this.nodes.filter(n => !n.id.includes('localhost'));
    otherNodes.forEach((node, index) => {
      const angle = (index / otherNodes.length) * 2 * Math.PI;
      node.x = centerX + Math.cos(angle) * radius;
      node.y = centerY + Math.sin(angle) * radius;
    });
  },
  
  startAnimation() {
    const animate = () => {
      this.pulseTime += 0.05;
      this.updateParticles();
      this.render();
      this.animationId = requestAnimationFrame(animate);
    };
    animate();
  },
  
  updateParticles() {
    this.particles = this.particles.filter(particle => {
      particle.progress += 0.02;
      particle.life -= 1;
      
      if (particle.progress >= 1 || particle.life <= 0) {
        return false;
      }
      
      // Update position along the edge
      particle.x = particle.x + (particle.targetX - particle.x) * 0.02;
      particle.y = particle.y + (particle.targetY - particle.y) * 0.02;
      
      return true;
    });
  },
  
  render() {
    // Clear canvas with dark background
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.1)';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    
    // Draw edges
    this.drawEdges();
    
    // Draw particles
    this.drawParticles();
    
    // Draw nodes
    this.drawNodes();
    
    // Draw grid background
    this.drawGrid();
  },
  
  drawGrid() {
    this.ctx.strokeStyle = 'rgba(120, 119, 198, 0.1)';
    this.ctx.lineWidth = 1;
    
    const gridSize = 50;
    
    // Vertical lines
    for (let x = 0; x < this.canvas.width; x += gridSize) {
      this.ctx.beginPath();
      this.ctx.moveTo(x, 0);
      this.ctx.lineTo(x, this.canvas.height);
      this.ctx.stroke();
    }
    
    // Horizontal lines
    for (let y = 0; y < this.canvas.height; y += gridSize) {
      this.ctx.beginPath();
      this.ctx.moveTo(0, y);
      this.ctx.lineTo(this.canvas.width, y);
      this.ctx.stroke();
    }
  },
  
  drawEdges() {
    this.edges.forEach(edge => {
      const fromNode = this.nodes.find(n => n.id === edge.from);
      const toNode = this.nodes.find(n => n.id === edge.to);
      
      if (fromNode && toNode) {
        this.ctx.strokeStyle = edge.status === 'connected' ? 
          'rgba(168, 85, 247, 0.6)' : 'rgba(239, 68, 68, 0.6)';
        this.ctx.lineWidth = 2;
        
        this.ctx.beginPath();
        this.ctx.moveTo(fromNode.x, fromNode.y);
        this.ctx.lineTo(toNode.x, toNode.y);
        this.ctx.stroke();
        
        // Draw pulse along the edge
        const pulsePos = (Math.sin(this.pulseTime) + 1) / 2;
        const pulseX = fromNode.x + (toNode.x - fromNode.x) * pulsePos;
        const pulseY = fromNode.y + (toNode.y - fromNode.y) * pulsePos;
        
        this.ctx.fillStyle = 'rgba(168, 85, 247, 0.8)';
        this.ctx.beginPath();
        this.ctx.arc(pulseX, pulseY, 3, 0, 2 * Math.PI);
        this.ctx.fill();
      }
    });
  },
  
  drawNodes() {
    this.nodes.forEach(node => {
      // Node status color
      let nodeColor;
      switch (node.status) {
        case 'online':
          nodeColor = '#10B981'; // green
          break;
        case 'offline':
          nodeColor = '#EF4444'; // red
          break;
        default:
          nodeColor = '#6B7280'; // gray
      }
      
      // Draw node background
      const isLocal = node.id.includes('localhost');
      const nodeRadius = isLocal ? 25 : 15;
      
      this.ctx.fillStyle = nodeColor;
      this.ctx.beginPath();
      this.ctx.arc(node.x, node.y, nodeRadius, 0, 2 * Math.PI);
      this.ctx.fill();
      
      // Draw node border
      this.ctx.strokeStyle = isLocal ? '#A855F7' : '#374151';
      this.ctx.lineWidth = isLocal ? 3 : 2;
      this.ctx.stroke();
      
      // Draw pulse effect for new nodes
      if (node.isNew) {
        const pulseRadius = nodeRadius + Math.sin(this.pulseTime * 3) * 10;
        this.ctx.strokeStyle = 'rgba(168, 85, 247, 0.5)';
        this.ctx.lineWidth = 2;
        this.ctx.beginPath();
        this.ctx.arc(node.x, node.y, pulseRadius, 0, 2 * Math.PI);
        this.ctx.stroke();
      }
      
      // Draw node label
      this.ctx.fillStyle = '#FFFFFF';
      this.ctx.font = isLocal ? '12px Arial' : '10px Arial';
      this.ctx.textAlign = 'center';
      this.ctx.fillText(
        node.name || node.id.split('.')[0], 
        node.x, 
        node.y + nodeRadius + 15
      );
      
      // Draw capabilities as small dots
      if (node.capabilities && node.capabilities.length > 0) {
        node.capabilities.slice(0, 4).forEach((capability, index) => {
          const capX = node.x - 15 + (index * 8);
          const capY = node.y - nodeRadius - 10;
          
          this.ctx.fillStyle = this.getCapabilityColor(capability);
          this.ctx.beginPath();
          this.ctx.arc(capX, capY, 2, 0, 2 * Math.PI);
          this.ctx.fill();
        });
      }
    });
  },
  
  drawParticles() {
    this.particles.forEach(particle => {
      const alpha = particle.life / particle.maxLife;
      this.ctx.fillStyle = `rgba(${particle.color.r}, ${particle.color.g}, ${particle.color.b}, ${alpha})`;
      
      this.ctx.beginPath();
      this.ctx.arc(particle.x, particle.y, 3, 0, 2 * Math.PI);
      this.ctx.fill();
      
      // Particle trail
      this.ctx.strokeStyle = `rgba(${particle.color.r}, ${particle.color.g}, ${particle.color.b}, ${alpha * 0.3})`;
      this.ctx.lineWidth = 1;
      this.ctx.beginPath();
      this.ctx.arc(particle.x, particle.y, 6, 0, 2 * Math.PI);
      this.ctx.stroke();
    });
  },
  
  getActivityColor(activityType) {
    switch (activityType) {
      case 'ThunderblockConnect':
        return { r: 34, g: 197, b: 94 }; // green
      case 'ThunderblockAnnounce':
        return { r: 168, g: 85, b: 247 }; // purple  
      case 'ThunderblockHealthCheck':
        return { r: 59, g: 130, b: 246 }; // blue
      default:
        return { r: 156, g: 163, b: 175 }; // gray
    }
  },
  
  getCapabilityColor(capability) {
    switch (capability) {
      case 'federation':
        return '#A855F7'; // purple
      case 'real_time':
        return '#10B981'; // green
      case 'data_collection':
        return '#F59E0B'; // yellow
      case 'ai_agents':
        return '#EF4444'; // red
      default:
        return '#6B7280'; // gray
    }
  }
};
