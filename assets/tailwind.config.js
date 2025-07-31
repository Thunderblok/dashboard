// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/thundertab_web.ex",
    "../lib/thundertab_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        // Thunderprism "Real-Talk" Neon Palette 
        neon: {
          cyan: "#00F5FF",
          magenta: "#FF3BE7", 
          yellow: "#FFC800",
          orange: "#FF7A00",
          purple: "#A84BFF",
        },
        bg: "#0B0C10",
        brand: "#FD4F00",
      },
      boxShadow: {
        neon: "0 0 8px rgba(0, 245, 255, 0.6), 0 0 16px rgba(0, 245, 255, 0.4)",
        "neon-magenta": "0 0 8px rgba(255, 59, 231, 0.6), 0 0 16px rgba(255, 59, 231, 0.4)",
        "neon-purple": "0 0 8px rgba(168, 75, 255, 0.6), 0 0 16px rgba(168, 75, 255, 0.4)",
        "neon-orange": "0 0 8px rgba(255, 122, 0, 0.6), 0 0 16px rgba(255, 122, 0, 0.4)",
        "neon-yellow": "0 0 8px rgba(255, 200, 0, 0.6), 0 0 16px rgba(255, 200, 0, 0.4)",
      },
      animation: {
        'sweep': 'sweep 6s linear infinite',
        'pulse-neon': 'pulse-neon 2s ease-in-out infinite alternate',
        'glow': 'glow 2s ease-in-out infinite alternate',
        'float': 'float 3s ease-in-out infinite',
      },
      fontFamily: {
        'sans': ['Inter', 'system-ui', 'sans-serif'],
        'mono': ['Space Mono', 'Fira Code', 'monospace'],
      },
      keyframes: {
        'sweep': {
          '0%': { 'background-position': '200% 0' },
          '100%': { 'background-position': '-200% 0' },
        },
        'pulse-neon': {
          'from': {
            'box-shadow': '0 0 4px currentColor, 0 0 8px currentColor, 0 0 16px currentColor',
          },
          'to': {
            'box-shadow': '0 0 8px currentColor, 0 0 16px currentColor, 0 0 32px currentColor',
          }
        },
        'glow': {
          'from': {
            'text-shadow': '0 0 4px currentColor, 0 0 8px currentColor',
          },
          'to': {
            'text-shadow': '0 0 8px currentColor, 0 0 16px currentColor, 0 0 24px currentColor',
          }
        },
        'float': {
          '0%, 100%': { transform: 'translateY(0px)' },
          '50%': { transform: 'translateY(-10px)' },
        }
      }
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("daisyui"),
    
    // Neon grid sweep and glow utilities
    function ({ addUtilities, addBase }) {
      addBase({
        '@import': [
          'url("https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap")',
          'url("https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&display=swap")'
        ]
      })
      
      addUtilities({
        '.bg-grid-sweep': {
          'background': 'linear-gradient(90deg, transparent 0%, rgba(0,245,255,.15) 50%, transparent 100%)',
          'background-size': '200% 1px',
          'animation': 'sweep 6s linear infinite',
        },
        '.text-neon-glow': {
          'text-shadow': '0 0 4px currentColor, 0 0 8px currentColor, 0 0 16px currentColor',
        },
        '.border-neon-glow': {
          'box-shadow': '0 0 4px currentColor, inset 0 0 4px currentColor',
        },
        '.backdrop-glass': {
          'backdrop-filter': 'blur(12px) saturate(1.2)',
          'background': 'rgba(0,0,0,0.3)',
        },
        '.neon-grid': {
          'background-image': 'radial-gradient(circle, rgba(0,245,255,0.3) 1px, transparent 1px)',
          'background-size': '20px 20px',
        }
      })
    },
    
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({addVariant}) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({addVariant}) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({addVariant}) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),

    // Embeds Heroicons (https://heroicons.com) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    //
    plugin(function({matchComponents, theme}) {
      let iconsDir = path.join(__dirname, "../deps/heroicons/optimized")
      let values = {}
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"],
        ["-micro", "/16/solid"]
      ]
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach(file => {
          let name = path.basename(file, ".svg") + suffix
          values[name] = {name, fullPath: path.join(iconsDir, dir, file)}
        })
      })
      matchComponents({
        "hero": ({name, fullPath}) => {
          let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
          let size = theme("spacing.6")
          if (name.endsWith("-mini")) {
            size = theme("spacing.5")
          } else if (name.endsWith("-micro")) {
            size = theme("spacing.4")
          }
          return {
            [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
            "-webkit-mask": `var(--hero-${name})`,
            "mask": `var(--hero-${name})`,
            "mask-repeat": "no-repeat",
            "background-color": "currentColor",
            "vertical-align": "middle",
            "display": "inline-block",
            "width": size,
            "height": size
          }
        }
      }, {values})
    })
  ],
  daisyui: {
    themes: [
      {
        thunderprism: {
          "primary": "#00F5FF",
          "secondary": "#FF3BE7", 
          "accent": "#A84BFF",
          "neutral": "#1a1a1a",
          "base-100": "#0B0C10",
          "base-200": "#111111",
          "base-300": "#1f1f1f",
          "info": "#00F5FF",
          "success": "#00ff88",
          "warning": "#FFC800",
          "error": "#ff4757",
        }
      }
    ]
  }
}
