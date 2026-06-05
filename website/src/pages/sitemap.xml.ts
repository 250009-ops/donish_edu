import type { APIRoute } from "astro";
import { SITE } from "../config/site";

const pages = [
  { path: "", priority: "1.0", changefreq: "weekly" },
  { path: "/home", priority: "0.9", changefreq: "weekly" },
  { path: "/privacy", priority: "0.4", changefreq: "monthly" },
  { path: "/terms", priority: "0.4", changefreq: "monthly" },
  { path: "/refund", priority: "0.4", changefreq: "monthly" }
];

export const GET: APIRoute = () => {
  const urls = pages
    .map(
      (p) => `  <url>
    <loc>${SITE.url}${p.path}</loc>
    <changefreq>${p.changefreq}</changefreq>
    <priority>${p.priority}</priority>
  </url>`
    )
    .join("\n");

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls}
</urlset>`;

  return new Response(xml, {
    headers: {
      "Content-Type": "application/xml; charset=utf-8"
    }
  });
};
