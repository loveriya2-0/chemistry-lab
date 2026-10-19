/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'system-ui', 'Segoe UI', 'sans-serif'],
        display: ['"Plus Jakarta Sans"', 'Inter', 'system-ui', 'sans-serif'],
      },
      colors: {
        brand: {
          50: '#f0f3ff', 100: '#e2e7ff', 200: '#c9d1ff', 300: '#a5b1fd', 400: '#8187f9',
          500: '#6463f2', 600: '#5145e5', 700: '#4537ca', 800: '#382fa3', 900: '#312c81', 950: '#1e1a4b',
        },
      },
      boxShadow: {
        soft: '0 1px 2px rgb(15 23 42 / 0.04), 0 4px 16px -4px rgb(15 23 42 / 0.06)',
        lift: '0 2px 4px rgb(15 23 42 / 0.05), 0 12px 32px -8px rgb(15 23 42 / 0.14)',
        glow: '0 8px 24px -6px rgb(81 69 229 / 0.45)',
      },
      keyframes: {
        'fade-up': { from: { opacity: '0', transform: 'translateY(6px)' }, to: { opacity: '1', transform: 'none' } },
      },
      animation: { 'fade-up': 'fade-up .35s ease-out both' },
    },
  },
  plugins: [],
};
