import { defineConfig } from "astro/config";

export default defineConfig({
  site: "https://donish.live",
  compressHTML: true,
  build: {
    inlineStylesheets: "auto"
  }
});
