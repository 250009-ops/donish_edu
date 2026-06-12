let accessToken: string | null = null;

export function setAccessToken(t: string | null) {
  accessToken = t;
}

export function getAccessToken() {
  return accessToken;
}

async function request(path: string, init: RequestInit = {}) {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(init.headers as Record<string, string>)
  };
  if (accessToken) headers.Authorization = `Bearer ${accessToken}`;
  const res = await fetch(`/admin${path}`, {
    ...init,
    headers,
    credentials: "include"
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || res.statusText);
  return data;
}

export const api = {
  login: (email: string, password: string) =>
    request("/auth/login", {
      method: "POST",
      body: JSON.stringify({ email, password })
    }),
  mfa: (mfa_token: string, code: string) =>
    request("/auth/2fa", {
      method: "POST",
      body: JSON.stringify({ mfa_token, code })
    }),
  refresh: () => request("/auth/refresh", { method: "POST" }),
  me: () => request("/auth/me"),
  threads: (q?: string) =>
    request(`/threads${q ? `?q=${encodeURIComponent(q)}` : ""}`),
  messages: (tid: number) => request(`/threads/${tid}/messages`),
  reply: (tid: number, body: string) =>
    request(`/threads/${tid}/reply`, {
      method: "POST",
      body: JSON.stringify({ body })
    }),
  users: (q?: string) =>
    request(`/users${q ? `?q=${encodeURIComponent(q)}` : ""}`),
  user: (id: string) => request(`/users/${id}`),
  limits: () => request("/limits"),
  updateLimits: (body: object) =>
    request("/limits", { method: "PUT", body: JSON.stringify(body) }),
  usageSummary: () => request("/usage/summary"),
  usageUsers: () => request("/usage/users"),
  broadcast: (body: string, audience = "all") =>
    request("/broadcast", {
      method: "POST",
      body: JSON.stringify({ body, audience })
    })
};
