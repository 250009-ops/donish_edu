import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  base: "/admin/",
  server: {
    port: 5174,
    proxy: {
      "/admin/auth": "http://localhost:4000",
      "/admin/threads": "http://localhost:4000",
      "/admin/users": "http://localhost:4000",
      "/admin/limits": "http://localhost:4000",
      "/admin/usage": "http://localhost:4000",
      "/admin/broadcast": "http://localhost:4000",
      "/admin/ws": { target: "ws://localhost:4000", ws: true }
    }
  }
});
