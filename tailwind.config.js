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
        // ── Vintage train palette: Tuscan Red / Maroon ──
        niknax: {
          50:  '#fdf5f3',
          100: '#fce8e4',
          200: '#f8cdc5',
          300: '#f29893',   // warm rose — headings in dark mode
          400: '#e06b62',   // copper-rose — links
          500: '#b83e2f',   // burnt sienna — hover state
          600: '#8B2635',   // Tuscan Red — primary buttons
          700: '#7a1f2d',
          800: '#601820',
          900: '#3d0f18',   // deep maroon — dark gradients
          950: '#1f0a0e',
        },
        // ── Antique Brass / Gold ──
        gold: {
          300: '#e8c97d',
          400: '#C9A227',   // antique gold accent
          500: '#a07d0a',
          600: '#7a5e08',
        }
      },
      fontFamily: {
        display: ['Playfair Display', 'Georgia', 'serif'],
        mono:    ['Courier Prime', 'Courier New', 'monospace'],
      }
    }
  },
  plugins: []
}
