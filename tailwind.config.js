/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{vue,js,ts}'],
  darkMode: 'class',
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
        // ── Vintage train palette: Deep Forest Green / Pullman ──
        niknax: {
          50:  '#f0faf5',
          100: '#d8f0e3',
          200: '#b2dfc5',
          300: '#7fc4a2',   // sage — headings / accents in dark
          400: '#52a882',   // medium sage — links
          500: '#2E8B57',   // sea green — hover
          600: '#1A5C38',   // deep forest — primary buttons
          700: '#154a2d',
          800: '#0f3a22',
          900: '#081C15',   // near-black green — dark bg
          950: '#040e0a',
        },
        // ── Antique Brass / Gold ──
        gold: {
          300: '#f0d27a',
          400: '#D4A017',   // antique gold
          500: '#b07d10',
          600: '#8a5f0a',
        }
      },
      fontFamily: {
        display: ['Abril Fatface', 'Georgia', 'serif'],
        mono:    ['Space Mono', 'Courier New', 'monospace'],
      }
    }
  },
  plugins: []
}
