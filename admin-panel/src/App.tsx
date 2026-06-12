import { useEffect, useState } from "react";
import { NavLink, Navigate, Route, Routes, useLocation, useNavigate } from "react-router-dom";
import { api, getAccessToken, setAccessToken } from "./api";

const LOGO = `${import.meta.env.BASE_URL}logo.png`;

const NAV = [
  { to: "/", label: "Support Inbox", icon: "💬", end: true },
  { to: "/users", label: "Users", icon: "👥" },
  { to: "/limits", label: "Limits", icon: "⚙️" },
  { to: "/usage", label: "OpenAI Usage", icon: "📊" },
  { to: "/broadcast", label: "Broadcast", icon: "📢" }
] as const;

function PageHeader({ title, subtitle }: { title: string; subtitle?: string }) {
  return (
    <header className="page-header">
      <h2>{title}</h2>
      {subtitle && <p>{subtitle}</p>}
    </header>
  );
}

function Login() {
  const nav = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [mfaToken, setMfaToken] = useState("");
  const [code, setCode] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      if (mfaToken) {
        const r = await api.mfa(mfaToken, code);
        setAccessToken(r.access);
        nav("/");
        return;
      }
      const r = await api.login(email, password);
      if (r.mfa_required) {
        setMfaToken(r.mfa_token);
        return;
      }
      setAccessToken(r.access);
      nav("/");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-page">
      <form className="login-card" onSubmit={submit}>
        <div className="login-brand">
          <img src={LOGO} alt="Gotcha" />
          <h1>Gotcha Admin</h1>
          <p>Secure control center for your platform</p>
        </div>

        {error && (
          <div className="alert-error" role="alert">
            <span>⚠</span>
            <span>{error}</span>
          </div>
        )}

        {!mfaToken ? (
          <>
            <div className="field">
              <label htmlFor="email">Email address</label>
              <input
                id="email"
                type="email"
                autoComplete="email"
                placeholder="you@company.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
            </div>
            <div className="field">
              <label htmlFor="password">Password</label>
              <div className="field-input-wrap">
                <input
                  id="password"
                  type={showPassword ? "text" : "password"}
                  autoComplete="current-password"
                  placeholder="Enter your password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                />
                <button
                  type="button"
                  className="password-toggle"
                  onClick={() => setShowPassword((v) => !v)}
                  tabIndex={-1}
                >
                  {showPassword ? "Hide" : "Show"}
                </button>
              </div>
            </div>
          </>
        ) : (
          <div className="field">
            <label htmlFor="code">Two-factor authentication code</label>
            <input
              id="code"
              inputMode="numeric"
              autoComplete="one-time-code"
              placeholder="6-digit code"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              required
            />
          </div>
        )}

        <button type="submit" className="btn btn-primary" disabled={loading}>
          {loading ? "Signing in…" : mfaToken ? "Verify & continue" : "Sign in to dashboard"}
        </button>

        <p className="login-footer">Protected by enterprise-grade authentication</p>
      </form>
    </div>
  );
}

function Shell({ children }: { children: React.ReactNode }) {
  const nav = useNavigate();
  const location = useLocation();
  const current = NAV.find((n) =>
    n.end ? location.pathname === n.to : location.pathname.startsWith(n.to)
  );

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <img src={LOGO} alt="Gotcha" />
          <div className="sidebar-brand-text">
            <h1>Gotcha</h1>
            <span>Admin Console</span>
          </div>
        </div>
        <nav className="sidebar-nav">
          {NAV.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) => `nav-link${isActive ? " active" : ""}`}
            >
              <span className="nav-icon">{item.icon}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-footer">
          <button
            type="button"
            className="btn btn-ghost"
            style={{ width: "100%" }}
            onClick={async () => {
              await api.refresh().catch(() => {});
              setAccessToken(null);
              nav("/login");
            }}
          >
            Sign out
          </button>
        </div>
      </aside>
      <div className="main-content">
        {current && (
          <PageHeader
            title={current.label}
            subtitle={
              current.to === "/"
                ? "Respond to user feedback in real time"
                : current.to === "/users"
                  ? "Search and manage registered accounts"
                  : current.to === "/limits"
                    ? "Configure global OpenAI and plan limits"
                    : current.to === "/usage"
                      ? "Monitor token consumption and estimated cost"
                      : "Send announcements via the Telegram bot"
            }
          />
        )}
        <div className="page-body">{children}</div>
      </div>
    </div>
  );
}

function Inbox() {
  const [threads, setThreads] = useState<any[]>([]);
  const [active, setActive] = useState<number | null>(null);
  const [messages, setMessages] = useState<any[]>([]);
  const [reply, setReply] = useState("");
  const [sending, setSending] = useState(false);

  useEffect(() => {
    api.threads().then((r) => setThreads(r.threads || []));
    const token = getAccessToken();
    if (!token) return;
    const ws = new WebSocket(
      `${location.protocol === "https:" ? "wss" : "ws"}://${location.host}/admin/ws?ticket=${token}`
    );
    ws.onmessage = () => api.threads().then((r) => setThreads(r.threads || []));
    return () => ws.close();
  }, []);

  useEffect(() => {
    if (!active) return;
    api.messages(active).then((r) => setMessages(r.messages || []));
  }, [active]);

  async function sendReply() {
    if (!active || !reply.trim() || sending) return;
    setSending(true);
    try {
      await api.reply(active, reply.trim());
      setReply("");
      const r = await api.messages(active);
      setMessages(r.messages || []);
    } finally {
      setSending(false);
    }
  }

  const activeThread = threads.find((t) => t.telegram_id === active);

  return (
    <div className="inbox-layout">
      <div className="card thread-list">
        <h3 className="card-title">Conversations</h3>
        <div className="thread-list-scroll">
          {threads.length === 0 ? (
            <div className="empty-state">
              <span className="icon">💬</span>
              <p>No messages yet</p>
            </div>
          ) : (
            threads.map((t) => (
              <div
                key={t.telegram_id}
                className={`thread-item${active === t.telegram_id ? " active" : ""}`}
                onClick={() => setActive(t.telegram_id)}
              >
                <div className="name">
                  {t.full_name || `User ${t.telegram_id}`}
                  {t.unread_count > 0 && (
                    <span className="badge" style={{ marginLeft: "0.5rem" }}>
                      {t.unread_count}
                    </span>
                  )}
                </div>
                <div className="preview">{t.last_body}</div>
              </div>
            ))
          )}
        </div>
      </div>

      <div className="card chat-panel">
        {active ? (
          <>
            <h3 className="card-title">
              {activeThread?.full_name || `Telegram ${active}`}
            </h3>
            <div className="messages">
              {messages.map((m) => (
                <div
                  key={m.id}
                  className={`msg ${m.direction === "in" ? "msg-in" : "msg-out"}`}
                >
                  {m.body}
                </div>
              ))}
            </div>
            <div className="reply-bar">
              <textarea
                value={reply}
                onChange={(e) => setReply(e.target.value)}
                placeholder="Type your reply to the user…"
                onKeyDown={(e) => {
                  if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    sendReply();
                  }
                }}
              />
              <button
                type="button"
                className="btn btn-primary"
                style={{ width: "auto", alignSelf: "flex-end" }}
                onClick={sendReply}
                disabled={sending || !reply.trim()}
              >
                {sending ? "Sending…" : "Send"}
              </button>
            </div>
          </>
        ) : (
          <div className="empty-state">
            <span className="icon">←</span>
            <p>Select a conversation to view messages and reply</p>
          </div>
        )}
      </div>
    </div>
  );
}

function Users() {
  const [users, setUsers] = useState<any[]>([]);
  const [q, setQ] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    api.users(q).then((r) => {
      setUsers(r.users || []);
      setLoading(false);
    });
  }, [q]);

  return (
    <>
      <div className="toolbar">
        <input
          className="search-input"
          placeholder="Search by name, email, phone, or Telegram ID…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
      </div>
      <div className="table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>Telegram ID</th>
              <th>Name</th>
              <th>Email</th>
              <th>Plan</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={4} style={{ textAlign: "center", padding: "2rem" }}>
                  Loading users…
                </td>
              </tr>
            ) : users.length === 0 ? (
              <tr>
                <td colSpan={4} style={{ textAlign: "center", padding: "2rem" }}>
                  No users found
                </td>
              </tr>
            ) : (
              users.map((u) => (
                <tr key={u.id}>
                  <td>{u.telegram_id}</td>
                  <td>{u.full_name || "—"}</td>
                  <td>{u.email || "—"}</td>
                  <td>
                    <span
                      className={`plan-badge ${u.plan === "premium" ? "plan-premium" : "plan-free"}`}
                    >
                      {u.plan || "free"}
                    </span>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}

const LIMIT_LABELS: Record<string, string> = {
  free_max_translate_total: "Free plan — lifetime translations",
  premium_max_translate_per_day: "Premium — translations per day",
  free_max_materials: "Free plan — max materials",
  max_devices_per_user: "Max devices per user"
};

function Limits() {
  const [limits, setLimits] = useState<any>({});
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    api.limits().then(setLimits);
  }, []);

  async function save() {
    setSaving(true);
    setSaved(false);
    try {
      await api.updateLimits(limits);
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="card" style={{ maxWidth: 560 }}>
      <h3 className="card-title">Global platform limits</h3>
      <div className="form-grid">
        {Object.keys(LIMIT_LABELS).map((k) => (
          <div className="field" key={k}>
            <label>{LIMIT_LABELS[k]}</label>
            <input
              type="number"
              min={0}
              value={limits[k] ?? ""}
              onChange={(e) => setLimits({ ...limits, [k]: Number(e.target.value) })}
            />
          </div>
        ))}
      </div>
      <div style={{ marginTop: "1.25rem", display: "flex", gap: "0.75rem", alignItems: "center" }}>
        <button type="button" className="btn btn-primary" style={{ width: "auto" }} onClick={save} disabled={saving}>
          {saving ? "Saving…" : "Save changes"}
        </button>
        {saved && <span style={{ color: "var(--success)", fontSize: "0.875rem" }}>✓ Saved</span>}
      </div>
    </div>
  );
}

function Usage() {
  const [summary, setSummary] = useState<any>(null);
  const [users, setUsers] = useState<any[]>([]);

  useEffect(() => {
    api.usageSummary().then(setSummary);
    api.usageUsers().then((r) => setUsers(r.users || []));
  }, []);

  return (
    <>
      <div className="stats-grid">
        <div className="stat-card">
          <div className="label">Total tokens</div>
          <div className="value">{summary?.totals?.total_tokens ?? "—"}</div>
        </div>
        <div className="stat-card">
          <div className="label">Est. cost (USD)</div>
          <div className="value">
            {summary?.totals?.total_cost_usd != null
              ? `$${Number(summary.totals.total_cost_usd).toFixed(4)}`
              : "—"}
          </div>
        </div>
        <div className="stat-card">
          <div className="label">API calls</div>
          <div className="value">{summary?.totals?.call_count ?? "—"}</div>
        </div>
      </div>
      <div className="table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              <th>User</th>
              <th>Tokens</th>
              <th>Cost (USD)</th>
              <th>Calls</th>
            </tr>
          </thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.user_id}>
                <td>{u.full_name || u.telegram_id || "—"}</td>
                <td>{u.tokens}</td>
                <td>{u.cost_usd != null ? Number(u.cost_usd).toFixed(4) : "—"}</td>
                <td>{u.calls}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}

function Broadcast() {
  const [body, setBody] = useState("");
  const [audience, setAudience] = useState("all");
  const [status, setStatus] = useState("");
  const [sending, setSending] = useState(false);

  async function send() {
    setSending(true);
    try {
      const r = await api.broadcast(body, audience);
      setStatus(`Broadcast started — job #${r.job.id} (${r.job.total_count} recipients)`);
      setBody("");
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="card" style={{ maxWidth: 640 }}>
      <h3 className="card-title">Send announcement</h3>
      <div className="form-grid">
        <div className="field">
          <label>Audience</label>
          <select value={audience} onChange={(e) => setAudience(e.target.value)}>
            <option value="all">All users</option>
            <option value="premium">Premium subscribers</option>
            <option value="free">Free plan users</option>
          </select>
        </div>
        <div className="field">
          <label>Message</label>
          <textarea
            rows={6}
            value={body}
            onChange={(e) => setBody(e.target.value)}
            placeholder="Write the message users will receive from the Gotcha Telegram bot…"
          />
        </div>
      </div>
      <button
        type="button"
        className="btn btn-primary"
        style={{ width: "auto", marginTop: "0.5rem" }}
        onClick={send}
        disabled={!body.trim() || sending}
      >
        {sending ? "Sending…" : "Send broadcast"}
      </button>
      {status && (
        <p style={{ marginTop: "1rem", color: "var(--success)", fontSize: "0.9rem" }}>{status}</p>
      )}
    </div>
  );
}

function Private({ children }: { children: React.ReactNode }) {
  const [ok, setOk] = useState<boolean | null>(null);

  useEffect(() => {
    if (!getAccessToken()) {
      api
        .refresh()
        .then((r) => {
          setAccessToken(r.access);
          setOk(true);
        })
        .catch(() => setOk(false));
    } else {
      setOk(true);
    }
  }, []);

  if (ok === null) {
    return (
      <div className="loading-screen">
        <div className="spinner" aria-label="Loading" />
      </div>
    );
  }
  if (!ok) return <Navigate to="/login" replace />;
  return <Shell>{children}</Shell>;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/" element={<Private><Inbox /></Private>} />
      <Route path="/users" element={<Private><Users /></Private>} />
      <Route path="/limits" element={<Private><Limits /></Private>} />
      <Route path="/usage" element={<Private><Usage /></Private>} />
      <Route path="/broadcast" element={<Private><Broadcast /></Private>} />
    </Routes>
  );
}
