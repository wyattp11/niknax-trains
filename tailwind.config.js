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
        // ── Mid-Century Modern palette: Eames Teal (brand) ──
        niknax: {
          50:  '#EAF6F3',
          100: '#CFEAE3',
          200: '#9DD4C6',
          300: '#6CBDAA',
          400: '#3FA28D',
          500: '#1F8772',   // hover
          600: '#156B59',   // primary buttons / brand
          700: '#105146',
          800: '#0B3A33',
          900: '#06231F',
          950: '#03110F',
        },
        // ── Burnt Orange / Coral accent ──
        teal: {
          300: '#F2A77C',
          400: '#EB8753',
          500: '#E26A33',
          600: '#C9531E',
          700: '#9E3F16',
        },
        // ── Mustard — sparing highlight accent ──
        mustard: {
          300: '#F0CD7E',
          400: '#E0B04E',
          500: '#D29A2C',
          600: '#B07F1F',
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
