/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{vue,js,ts}'],
  darkMode: 'class',
  // Status badge/chip classes are built dynamically (`badge-${...}`), so
  // Tailwind's content scanner never sees the literal class names and would
  // otherwise purge these hand-written @layer components rules in production.
  safelist: [
    'badge-live', 'badge-upcoming', 'badge-draft', 'badge-full',
    'chip-live', 'chip-upcoming', 'chip-draft', 'chip-full',
  ],
  theme: {
    extend: {
      colors: {
        // ── Semantic surface / text tokens (driven by CSS variables) ──
        base:    'var(--color-base)',
        surface: 'var(--color-surface)',
        sur2:    'var(--color-sur2)',
        bd:      'var(--color-bd)',
        bd2:     'var(--color-bd2)',
        tx1:     'var(--color-tx1)',
        tx2:     'var(--color-tx2)',
        tx3:     'var(--color-tx3)',
        // ── Mid-Century Postal palette: Slate Blue (brand) ──
        // Blue/orange pairing (not red/green) so brand vs. accent stays
        // distinguishable under protanopia/deuteranopia/tritanopia, and every
        // text/button pairing below clears WCAG AA contrast (4.5:1+).
        niknax: {
          50:  '#EFF5F8',
          100: '#DCEAF0',
          200: '#B9D5E1',
          300: '#93BECF',
          400: '#6CA3B9',
          500: '#4A86A0',   // hover (lighter slate blue)
          600: '#2C5F7C',   // primary buttons / brand — Slate Blue
          700: '#234C64',
          800: '#1B3A4D',
          900: '#122736',
          950: '#0A161F',
        },
        // ── Persimmon accent ──
        teal: {
          300: '#E8A688',
          400: '#DC7C54',
          500: '#C9522E',   // Persimmon
          600: '#A8401F',
          700: '#803117',
        },
        // ── Goldenrod — sparing highlight accent ──
        mustard: {
          300: '#E8CB85',
          400: '#C9962A',   // Goldenrod
          500: '#A87D20',
          600: '#876316',
        },
        // ── Walnut Brown — tertiary accent ──
        olive: {
          300: '#C9B29E',
          400: '#AD8F76',
          500: '#8C6B52',
          600: '#6B4A33',   // Walnut Brown
          700: '#4F3625',
        },
      },
      fontFamily: {
        display: ['Righteous', 'Impact', 'sans-serif'],
        sans:    ['DM Sans', 'system-ui', 'sans-serif'],
        mono:    ['Space Mono', 'Courier New', 'monospace'],
      }
    }
  },
  plugins: []
}
