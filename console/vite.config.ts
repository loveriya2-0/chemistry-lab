import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // Dev only: forward /api to the backend so no CORS setup is needed locally.
    proxy: { '/api': 'http://localhost:4000' },
  },
});
