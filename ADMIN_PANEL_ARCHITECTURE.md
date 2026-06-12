# Gotcha Web Admin Panel — Architecture

Status: **Design / pre-build**. Companion to `BOT_FLOW_ARCHITECTURE.md`. This is the
secure web console where the team manages users, OpenAI limits/usage, broadcasts, and a
two-way support inbox connected to the Telegram bot.

---

## 1. Goals & confirmed decisions

| Topic | Decision |
|---|---|
| Frontend stack | **React + Vite SPA** (TypeScript) |
| Backend | New **`/admin/*` API** on the existing Node/Express server + Postgres |
| Auth | **Email + password (bcrypt) + TOTP 2FA**, JWT sessions, rate-limited |
| Real-time | **WebSocket** live inbox/notifications, with polling fallback |
| Hosting | **`donish.live/admin`** (subpath) on the same VPS, behind nginx + TLS |
| Features | Support **inbox + reply**, **user management**, **OpenAI limits**, **usage dashboard**, **broadcast** |
| Limit behavior | On limit hit → **block + friendly "limit reached / upgrade" message** |

Security baseline additions (for "high security"): an **admin audit log** and
**admin session revocation** are included as part of the security design even though not
explicitly requested — they're standard for an admin console handling user data.

---

## 2. High-level architecture

```
                         donish.live/admin  (nginx + TLS, same VPS)
                         ┌──────────────────────────────────────────┐
   Browser (admin) ────► │  React + Vite SPA (static build)          │
                         │  - Access token in memory                 │
                         │  - Refresh token in httpOnly cookie       │
                         └───────────────┬───────────────┬──────────┘
                            HTTPS JSON    │               │  WSS
                                          ▼               ▼
                         ┌──────────────────────────────────────────┐
                         │  Express  /admin/* API  +  /admin/ws       │
                         │  requireAdminAuth (JWT) · RBAC · rate-limit│
                         │  audit-log middleware                      │
                         └───────┬───────────────┬───────────────────┘
                                 │               │
              ┌──────────────────┘               └────────────────────┐
              ▼                                                        ▼
   ┌────────────────────────┐                          ┌──────────────────────────┐
   │ Postgres                │                          │ Telegram Bot (Telegraf)  │
   │ admin_users, support_*, │  reply / broadcast ────► │ sendMessage(telegram_id) │
   │ user_limits, usage_*,   │ ◄──── inbound feedback   │ (shared bot instance)    │
   │ admin_audit_log         │       (WS push)          └──────────────────────────┘
   └────────────────────────┘
```

- The admin API lives in the **same Express process** as the bot, so replying/broadcast
  can call the existing Telegraf instance directly (no cross-service hop).
- Because the SPA is same-origin (`donish.live/admin` → same `donish.live` API),
  **CORS stays locked** (no wildcard for `/admin`); the current `cors({origin:'*'})` is
  scoped to public routes only.

---

## 3. Security model ("high security")

### 3.1 Authentication

- **`admin_users`** table: `email` (unique), `password_hash` (bcrypt, cost ≥ 12),
  `totp_secret` (encrypted at rest), `totp_enabled`, `role`, `is_active`,
  `failed_attempts`, `locked_until`, `last_login_at`.
- **Login flow (two-step)**:
  1. `POST /admin/auth/login { email, password }` → verify bcrypt. If `totp_enabled`,
     return a short-lived (`~5 min`) **MFA challenge token** (not a full session).
  2. `POST /admin/auth/2fa { mfa_token, code }` → verify TOTP (RFC 6238, 30s window,
     ±1 step). On success issue tokens.
- **Tokens**:
  - **Access token** (JWT, `ADMIN_JWT_SECRET`, ~15–30 min) — held in memory in the SPA,
    sent as `Authorization: Bearer`.
  - **Refresh token** — random opaque, stored hashed in `admin_sessions`, delivered as a
    **httpOnly, Secure, SameSite=Strict cookie** scoped to `/admin`. `POST
    /admin/auth/refresh` rotates it (rotation + reuse detection → revoke session).
- **2FA enrollment**: `POST /admin/auth/setup-2fa` returns an otpauth URI + QR; confirmed
  with a code before `totp_enabled = true`. Recovery codes (hashed) generated once.

### 3.2 Hardening

- **Brute-force protection**: per-email + per-IP rate limits on login/2fa; lockout after
  N failures (`locked_until`).
- **RBAC**: roles `superadmin` (manage admins + everything) and `support` (inbox + read
  users, no limit/billing changes). Enforced per-route.
- **Audit log**: `admin_audit_log` records every mutating admin action (who, what,
  target, before/after, IP, UA, time).
- **Transport/headers**: TLS only; `helmet` with strict CSP for `/admin` static assets;
  HSTS at nginx. No third-party scripts in the SPA.
- **Session controls**: list/revoke active admin sessions; force-logout; idle + absolute
  session timeouts.
- **Optional IP allowlist** for `/admin` via env (`ADMIN_IP_ALLOWLIST`) and/or nginx.
- **Secrets**: `ADMIN_JWT_SECRET`, `ADMIN_TOTP_ENC_KEY` validated at boot in
  `validateDeploymentConfig()` (min length, not placeholder), like existing secrets.
- **No public signup**: admins are seeded via a CLI script (`scripts/create-admin.mjs`)
  or created by a `superadmin` in-panel.

---

## 4. Data model (new tables)

```sql
-- Admin accounts
create table if not exists admin_users (
  id              bigserial primary key,
  email           text not null unique,
  password_hash   text not null,
  totp_secret     text,                       -- encrypted (ADMIN_TOTP_ENC_KEY)
  totp_enabled    boolean not null default false,
  role            text not null default 'support',  -- 'superadmin' | 'support'
  is_active       boolean not null default true,
  failed_attempts integer not null default 0,
  locked_until    timestamptz,
  last_login_at   timestamptz,
  created_at      timestamptz not null default now()
);

-- Refresh sessions (rotation + revocation)
create table if not exists admin_sessions (
  id              bigserial primary key,
  admin_id        bigint not null references admin_users(id) on delete cascade,
  refresh_hash    text not null,
  user_agent      text,
  ip              text,
  revoked_at      timestamptz,
  expires_at      timestamptz not null,
  created_at      timestamptz not null default now()
);

-- One-time recovery codes (hashed)
create table if not exists admin_recovery_codes (
  id        bigserial primary key,
  admin_id  bigint not null references admin_users(id) on delete cascade,
  code_hash text not null,
  used_at   timestamptz
);

-- Audit trail of admin actions
create table if not exists admin_audit_log (
  id         bigserial primary key,
  admin_id   bigint references admin_users(id) on delete set null,
  action     text not null,                   -- 'reply', 'set_user_limit', 'ban_user', ...
  target     text,                            -- e.g. user uuid / telegram_id
  meta       jsonb not null default '{}'::jsonb,
  ip         text,
  created_at timestamptz not null default now()
);

-- Global limit settings (single row, id = true)
create table if not exists usage_limits_global (
  id                          boolean primary key default true check (id),
  free_max_translate_total    integer not null default 5,
  premium_max_translate_per_day integer not null default 500,
  free_max_materials          integer not null default 1,
  max_devices_per_user        integer not null default 3,
  updated_by                  bigint,
  updated_at                  timestamptz not null default now()
);

-- Per-user overrides (null column = "use global/plan default")
create table if not exists user_limits (
  user_id                       uuid primary key references users(id) on delete cascade,
  translate_total_override      integer,     -- free-plan lifetime cap override
  translate_per_day_override    integer,     -- daily cap override (any plan)
  materials_override            integer,
  max_devices_override          integer,
  is_blocked                    boolean not null default false,  -- hard block of OpenAI actions
  note                          text,
  updated_by                    bigint,
  updated_at                    timestamptz not null default now()
);

-- OpenAI usage events (for dashboard + cost), one row per API call
create table if not exists openai_usage_events (
  id                bigserial primary key,
  user_id           uuid references users(id) on delete set null,
  action            text not null,           -- 'translate' | 'extract_pdf' | 'extract_image'
  model             text,
  prompt_tokens     integer,
  completion_tokens integer,
  total_tokens      integer,
  cost_usd          numeric(10,5),
  created_at        timestamptz not null default now()
);
create index if not exists openai_usage_user_day_idx
  on openai_usage_events (user_id, created_at desc);
create index if not exists openai_usage_action_idx
  on openai_usage_events (action, created_at desc);
```

`support_messages` is defined in `BOT_FLOW_ARCHITECTURE.md` §7.7 (shared between bot and
panel). Existing `usage_daily` (translate counters) is reused for limit enforcement.

---

## 5. OpenAI limits & usage

### 5.1 Effective-limit resolution

Today limits come straight from env `config` and are checked in `planMiddleware.js`.
We make them **layered**, resolved per request:

```
effective_limit(user, key) =
   user_limits.<key>_override            // per-user (if set)
   ?? usage_limits_global.<key>          // admin global default (DB)
   ?? config.<key>                       // env fallback (current behavior)
```

- Refactor `planMiddleware.js` to call a new `getEffectiveLimits(userId)` service instead
  of reading `config.*` directly. Behavior is identical until an admin changes a value.
- `user_limits.is_blocked = true` → all OpenAI-backed actions (translate, extraction)
  are blocked immediately with the friendly message, independent of counts.
- Limits are **cached briefly** (e.g. 30–60s in-memory) to avoid a DB hit per translate.

### 5.2 Enforcement points (unchanged endpoints, new source of truth)

| Action | Endpoint | OpenAI? | Limit key(s) |
|---|---|---|---|
| Word translate | `POST /translate` | yes (1–2 calls) | `translate_per_day` (premium) / `translate_total` (free), `is_blocked` |
| PDF extract | `POST /materials/extract-preview` | yes | `materials`, `is_blocked` |
| Image extract | `POST /materials/extract-preview` | yes | `materials`, `is_blocked` |

### 5.3 Friendly limit message (decision: block_friendly)

On limit hit the API returns the existing shape (`403 { code, error, limit, usage }`),
with localized, friendly copy, e.g.:

> "You've reached your free translation limit (5). Upgrade to Premium for unlimited
> translations 💎" — with an upgrade CTA in the app.

The Flutter app already handles `code: 'upgrade_required'`; we keep that contract.

### 5.4 Usage tracking

- Wrap OpenAI calls in a helper `callOpenAI(action, userId, payload)` that records an
  `openai_usage_events` row using `response.data.usage` (prompt/completion/total tokens)
  and a computed `cost_usd` from a per-model price map in config.
- Dashboard aggregates: tokens & cost per user, per action, per day; top consumers;
  totals over a date range.

---

## 6. Admin API surface (`/admin/*`)

All routes (except auth) require `requireAdminAuth` + RBAC + audit logging on mutations.

```
# Auth
POST   /admin/auth/login          { email, password } -> { mfa_token } | { tokens }
POST   /admin/auth/2fa            { mfa_token, code } -> { access, sets refresh cookie }
POST   /admin/auth/refresh        (cookie) -> { access } (rotates refresh)
POST   /admin/auth/logout         -> revokes session
POST   /admin/auth/setup-2fa      -> { otpauth_uri, qr } ; confirm with code
GET    /admin/me                  -> current admin + role

# Support inbox (two-way)
GET    /admin/threads             ?q&unread  -> users w/ last msg + unread count
GET    /admin/threads/:tid/messages ?before  -> paginated thread
POST   /admin/threads/:tid/reply  { body } -> stores 'out' + bot.sendMessage()
POST   /admin/threads/:tid/read   -> mark inbound read

# Users
GET    /admin/users               ?q&plan&page
GET    /admin/users/:id           -> profile, plan, devices, usage summary, limits
POST   /admin/users/:id/ban       { blocked: true|false }  (sets user_limits.is_blocked)
POST   /admin/users/:id/reset-password { password }
GET    /admin/users/:id/devices   /  DELETE .../devices/:deviceId

# OpenAI limits
GET    /admin/limits              -> global defaults
PUT    /admin/limits              { ...global }            (superadmin)
GET    /admin/users/:id/limits    -> effective + overrides
PUT    /admin/users/:id/limits    { overrides }            (superadmin)

# Usage dashboard
GET    /admin/usage/summary       ?from&to        -> totals, cost, by action
GET    /admin/usage/users         ?from&to&sort   -> per-user tokens/cost (top consumers)

# Broadcast
POST   /admin/broadcast           { body, audience } -> creates job
GET    /admin/broadcast/:id       -> progress (sent/failed)

# Realtime
WS     /admin/ws                  (auth via short-lived ticket) -> inbound msgs, unread, job progress
```

### 6.1 WebSocket

- Auth: SPA requests a short-lived **WS ticket** from an authed HTTP endpoint, then
  connects `wss://donish.live/admin/ws?ticket=…` (nginx `Upgrade` proxied).
- Server → client events: `support:new` (new inbound message), `support:read`,
  `broadcast:progress`. Fallback: if WS drops, SPA polls `GET /admin/threads?unread`.

### 6.2 Broadcast delivery

- Broadcast writes a `broadcast_jobs` row and fans out via a queue that respects Telegram
  limits (~30 msgs/sec, backoff on 429). Tracks sent/failed per recipient. Audience
  options: all users / premium / free / specific language.

---

## 7. Frontend (React + Vite SPA)

- Routes: `/admin/login`, `/admin` (dashboard), `/admin/inbox`, `/admin/users`,
  `/admin/users/:id`, `/admin/limits`, `/admin/usage`, `/admin/broadcast`,
  `/admin/settings` (admins, sessions, 2FA).
- State/data: lightweight (e.g. React Query) for API; a WS hook for live inbox.
- **Inbox UX**: chat-style — left list of threads (avatar = name/telegram_id, unread
  badge, last message), right pane = conversation with a reply box; new inbound messages
  appear live and bump the thread to top.
- **Auth handling**: access token in memory; silent refresh via cookie; auto-logout on
  401/expiry; 2FA screens.
- Built to static assets, served by nginx at `/admin/` with SPA fallback
  (`try_files ... /admin/index.html`).

---

## 8. Backend module layout (additions)

```
backend/src/
  routes/admin/
    auth.js          # login, 2fa, refresh, logout, setup-2fa
    threads.js       # support inbox + reply
    users.js         # user management
    limits.js        # global + per-user limits
    usage.js         # usage dashboards
    broadcast.js     # broadcast jobs
  middlewares/
    adminAuth.js     # requireAdminAuth + RBAC
    adminAudit.js    # audit-log wrapper
    adminRateLimits.js
  services/
    adminAuthService.js     # bcrypt, TOTP, sessions
    supportService.js       # support_messages CRUD + bot relay
    limitsService.js        # getEffectiveLimits(), cache
    openaiUsageService.js   # record + aggregate usage
    broadcastService.js     # queued fan-out
  ws/adminSocket.js  # WebSocket server + ticket auth
  realtime/bus.js    # in-process event emitter (support:new, etc.)
scripts/create-admin.mjs    # seed first superadmin (email+password, prints 2FA setup)
```

- A small **in-process event bus** decouples "bot received feedback" from "push to WS"
  (the bot handler emits `support:new`; the WS layer subscribes).

---

## 9. Config / env additions

```
ADMIN_JWT_SECRET=            # >=32 random chars, distinct from JWT_SECRET
ADMIN_TOTP_ENC_KEY=          # 32-byte key to encrypt TOTP secrets at rest
ADMIN_ACCESS_TTL=30m
ADMIN_REFRESH_TTL=7d
ADMIN_IP_ALLOWLIST=          # optional CSV of allowed IPs/CIDRs
OPENAI_PRICE_PER_1K_INPUT=   # for cost_usd estimate (per model, optional map)
OPENAI_PRICE_PER_1K_OUTPUT=
```

`validateDeploymentConfig()` extended to require `ADMIN_JWT_SECRET` and
`ADMIN_TOTP_ENC_KEY` in production.

---

## 10. Deployment (donish.live/admin)

- Build the SPA → static files served by nginx under `location /admin/` with SPA
  fallback.
- `location /admin/api/` (or reuse `/admin/*` on the API) proxied to the Node app;
  WebSocket `location /admin/ws` with `proxy_set_header Upgrade`/`Connection`.
- TLS + HSTS already handled by the existing nginx config (`backend/nginx-donish*.conf`)
  — add the `/admin` blocks there.
- Optional: nginx `allow/deny` for IP allowlisting; `limit_req` on `/admin/api/auth`.

---

## 11. Build phases (admin = bot Phase 6, broken down)

- **6.1 — Foundations**: migrations (admin_users, sessions, audit, limits, usage,
  support already from Phase 4); `create-admin.mjs`; admin JWT/TOTP config + validation.
- **6.2 — Admin auth API + SPA shell**: login + 2FA + refresh + RBAC; React shell, login
  screens, protected routing; nginx `/admin` wiring.
- **6.3 — Support inbox**: `supportService`, threads API, reply→bot relay, WebSocket live
  inbox; connect bot `SUPPORT_CHAT` (Phase 4) to the event bus.
- **6.4 — OpenAI limits**: `limitsService.getEffectiveLimits()`, refactor
  `planMiddleware` to use it, global + per-user limit screens, friendly-block copy.
- **6.5 — Usage dashboard**: `callOpenAI` usage recording in translate + extraction,
  aggregation endpoints, dashboard charts.
- **6.6 — User management + broadcast**: user search/detail/ban/reset/devices; broadcast
  job + queued fan-out + progress.
- **6.7 — Hardening pass**: audit-log coverage, session revocation UI, rate-limit/lockout
  tuning, optional IP allowlist, CSP.

---

## 12. Decisions & remaining inputs

Defaults applied (changeable later):

- **Audit log: included** in the security baseline (`admin_audit_log`).
- **Subscription/billing management: deferred** — not in the initial admin scope. The
  user record/detail view will *display* plan/premium status (read-only); granting
  premium from the panel is a later add-on.
- **Admin roles**: two roles — `superadmin` / `support`.
- **OpenAI cost**: dashboard shows $ cost using a configurable per-model price map (plus
  raw tokens/counts).
- **Inbox reply identity**: replies are branded "Support"; individual admins are not
  named to users.

Still needed (only when we build the relevant phase):

- **Broadcast audience** — confirm segments (all / premium / free / by language) at 6.6.
- **First admin** — the seed `superadmin` email/password for `create-admin.mjs` at 6.1.
