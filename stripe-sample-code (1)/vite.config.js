import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    // Proxy API requests to server
    proxy: {
      "/api": "http://localhost:4242",
    },
  },
});