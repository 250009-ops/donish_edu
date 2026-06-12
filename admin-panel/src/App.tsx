import { useEffect, useState } from "react";
import { NavLink, Navigate, Route, Routes, useNavigate } from "react-router-dom";
import { api, getAccessToken, setAccessToken } from "./api";

function Login() {
  const nav = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [mfaToken, setMfaToken] = useState("");
  const [code, setCode] = useState("");
  const [error, setError] = useState("");

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
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
    }
  }

  return (
    <div className="login-wrap">
      <form className="card login-card" onSubmit={submit}>
        <h2>Gotcha Admin</h2>
        {error && <p className="error">{error}</p>}
        {!mfaToken ? (
          <>
            <label>Email</label>
            <input value={email} onChange={(e) => setEmail(e.target.value)} type="email" required />
            <label>Password</label>
            <input value={password} onChange={(e) => setPassword(e.target.value)} type="password" required />
          </>
        ) : (
          <>
            <label>2FA code</label>
            <input value={code} onChange={(e) => setCode(e.target.value)} required />
          </>
        )}
        <button type="submit">{mfaToken ? "Verify" : "Sign in"}</button>
      </form>
    </div>
  );
}

function Shell({ children }: { children: React.ReactNode }) {
  const nav = useNavigate();
  return (
    <div className="layout">
      <aside className="sidebar">
        <h1>Gotcha Admin</h1>
        <nav>
          <NavLink to="/" end>Inbox</NavLink>
          <NavLink to="/users">Users</NavLink>
          <NavLink to="/limits">Limits</NavLink>
          <NavLink to="/usage">Usage</NavLink>
          <NavLink to="/broadcast">Broadcast</NavLink>
        </nav>
        <button
          style={{ marginTop: "2rem", width: "100%" }}
          onClick={async () => {
            await api.refresh().catch(() => {});
            setAccessToken(null);
            nav("/login");
          }}
        >
          Log out
        </button>
      </aside>
      <main className="main">{children}</main>
    </div>
  );
}

function Inbox() {
  const [threads, setThreads] = useState<any[]>([]);
  const [active, setActive] = useState<number | null>(null);
  const [messages, setMessages] = useState<any[]>([]);
  const [reply, setReply] = useState("");

  useEffect(() => {
    api.threads().then((r) => setThreads(r.threads || []));
    const ws = new WebSocket(
      `${location.protocol === "https:" ? "wss" : "ws"}://${location.host}/admin/ws?ticket=${getAccessToken()}`
    );
    ws.onmessage = () => api.threads().then((r) => setThreads(r.threads || []));
    return () => ws.close();
  }, []);

  useEffect(() => {
    if (!active) return;
    api.messages(active).then((r) => setMessages(r.messages || []));
  }, [active]);

  async function sendReply() {
    if (!active || !reply.trim()) return;
    await api.reply(active, reply.trim());
    setReply("");
    const r = await api.messages(active);
    setMessages(r.messages || []);
  }

  return (
    <div className="inbox">
      <div className="card thread-list">
        <h3>Threads</h3>
        {threads.map((t) => (
          <div
            key={t.telegram_id}
            className={`thread-item ${active === t.telegram_id ? "active" : ""}`}
            onClick={() => setActive(t.telegram_id)}
          >
            <strong>{t.full_name || t.telegram_id}</strong>
            {t.unread_count > 0 && ` (${t.unread_count})`}
            <div style={{ fontSize: "0.8rem", opacity: 0.7 }}>{t.last_body}</div>
          </div>
        ))}
      </div>
      <div className="card">
        {active ? (
          <>
            <h3>Chat {active}</h3>
            <div className="messages">
              {messages.map((m) => (
                <div key={m.id} className={m.direction === "in" ? "msg-in" : "msg-out"}>
                  {m.body}
                </div>
              ))}
            </div>
            <div className="reply-row">
              <textarea value={reply} onChange={(e) => setReply(e.target.value)} placeholder="Reply…" />
              <button onClick={sendReply}>Send</button>
            </div>
          </>
        ) : (
          <p>Select a thread</p>
        )}
      </div>
    </div>
  );
}

function Users() {
  const [users, setUsers] = useState<any[]>([]);
  const [q, setQ] = useState("");
  useEffect(() => {
    api.users(q).then((r) => setUsers(r.users || []));
  }, [q]);
  return (
    <div>
      <h2>Users</h2>
      <input placeholder="Search…" value={q} onChange={(e) => setQ(e.target.value)} />
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Email</th>
            <th>Plan</th>
          </tr>
        </thead>
        <tbody>
          {users.map((u) => (
            <tr key={u.id}>
              <td>{u.telegram_id}</td>
              <td>{u.full_name || "—"}</td>
              <td>{u.email || "—"}</td>
              <td>{u.plan || "free"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Limits() {
  const [limits, setLimits] = useState<any>({});
  useEffect(() => {
    api.limits().then(setLimits);
  }, []);
  async function save() {
    await api.updateLimits(limits);
    alert("Saved");
  }
  return (
    <div>
      <h2>Global limits</h2>
      <div className="card">
        {[
          "free_max_translate_total",
          "premium_max_translate_per_day",
          "free_max_materials",
          "max_devices_per_user"
        ].map((k) => (
          <div key={k} style={{ marginBottom: "0.75rem" }}>
            <label>{k}</label>
            <input
              type="number"
              value={limits[k] ?? ""}
              onChange={(e) => setLimits({ ...limits, [k]: Number(e.target.value) })}
              style={{ width: "100%", marginTop: "0.25rem" }}
            />
          </div>
        ))}
        <button onClick={save}>Save</button>
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
    <div>
      <h2>OpenAI usage</h2>
      {summary && (
        <div className="card">
          <p>Total tokens: {summary.totals?.total_tokens}</p>
          <p>Est. cost USD: {summary.totals?.total_cost_usd}</p>
          <p>API calls: {summary.totals?.call_count}</p>
        </div>
      )}
      <table>
        <thead>
          <tr>
            <th>User</th>
            <th>Tokens</th>
            <th>Cost</th>
          </tr>
        </thead>
        <tbody>
          {users.map((u) => (
            <tr key={u.user_id}>
              <td>{u.full_name || u.telegram_id}</td>
              <td>{u.tokens}</td>
              <td>{u.cost_usd}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Broadcast() {
  const [body, setBody] = useState("");
  const [audience, setAudience] = useState("all");
  const [status, setStatus] = useState("");
  async function send() {
    const r = await api.broadcast(body, audience);
    setStatus(`Job #${r.job.id} started (${r.job.total_count} users)`);
    setBody("");
  }
  return (
    <div>
      <h2>Broadcast</h2>
      <div className="card">
        <select value={audience} onChange={(e) => setAudience(e.target.value)}>
          <option value="all">All users</option>
          <option value="premium">Premium</option>
          <option value="free">Free</option>
        </select>
        <textarea
          style={{ width: "100%", marginTop: "0.75rem", minHeight: 120 }}
          value={body}
          onChange={(e) => setBody(e.target.value)}
          placeholder="Message to send via Telegram bot…"
        />
        <button style={{ marginTop: "0.75rem" }} onClick={send} disabled={!body.trim()}>
          Send broadcast
        </button>
        {status && <p>{status}</p>}
      </div>
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
  if (ok === null) return <p>Loading…</p>;
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
