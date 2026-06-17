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
        // ── Mod Citrus palette: Tangerine (brand) ──
        niknax: {
          50:  '#FFFAF2',
          100: '#FDF0DE',
          200: '#FCE6C9',
          300: '#FAD9B0',
          400: '#F7C58D',
          500: '#F4A857',   // hover (lighter tangerine)
          600: '#F08C2E',   // primary buttons / brand — Tangerine
          700: '#C96F1E',
          800: '#9E5716',
          900: '#6B3B0F',
          950: '#3A1F08',
        },
        // ── Hot Pink accent ──
        teal: {
          300: '#F2A0C2',
          400: '#EB6FA0',
          500: '#E0488B',   // Hot Pink
          600: '#C2316F',
          700: '#97225A',
        },
        // ── Lemon — sparing highlight accent ──
        mustard: {
          300: '#F7E48A',
          400: '#F2D43D',   // Lemon
          500: '#DCC02C',
          600: '#B89F1F',
        },
        // ── Olive — tertiary accent ──
        olive: {
          300: '#C2CE9E',
          400: '#A9B97D',
          500: '#8B9F5C',
          600: '#6B7A3A',   // Olive
          700: '#56612D',
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
