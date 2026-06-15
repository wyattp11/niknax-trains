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
        // ── 60s Mod palette: Warm Orange / Space Age ──
        niknax: {
          50:  '#fff8f0',
          100: '#feecdc',
          200: '#fcd5b4',
          300: '#f9b580',
          400: '#f58c47',
          500: '#EF5A0A',   // 60s orange — hover
          600: '#D44400',   // bold orange — primary buttons / brand
          700: '#AA3600',
          800: '#7A2700',
          900: '#421400',
          950: '#200900',
        },
        // ── Teal / Turquoise accent ──
        teal: {
          300: '#5CD6CC',
          400: '#2BBFB4',
          500: '#009B8F',
          600: '#007A70',
          700: '#005C55',
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
