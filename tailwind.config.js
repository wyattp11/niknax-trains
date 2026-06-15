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
        // ── 60s Mod palette: Red / Hot Pink ──
        niknax: {
          50:  '#fff0f4',
          100: '#ffdde6',
          200: '#ffb3c6',
          300: '#ff80a3',
          400: '#ff4d7e',
          500: '#E8005A',   // hot pink — hover
          600: '#C8002A',   // bold red — primary buttons / brand
          700: '#9A001E',
          800: '#6E0015',
          900: '#3D000C',
          950: '#1A0006',
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
