# PaperclipEx — Technical Specifications
## Version 0.1.0 | Production-Grade Elixir/Phoenix AI Agent Orchestration

---

## 1. SYSTEM OVERVIEW

PaperclipEx is the production-grade, Elixir/Phoenix/Ash Framework rebuild of the Paperclip
AI agent orchestration platform. It is a **control plane** — it does not run AI agents
directly, it orchestrates them. Agents run externally (CLI tools, HTTP endpoints, Elixir
modules) and interact with PaperclipEx via a REST API during heartbeat execution windows.

**Design axiom:** Every architectural decision must be justified by either fault tolerance,
operational correctness, or developer experience. No decisions driven by "what Paperclip does."

---

## 2. TECHNOLOGY STACK

### Runtime
| Component | Technology | Version | Justification |
|---|---|---|---|
| Language | Elixir | 1.17+ | BEAM process model = native agent isolation |
| Runtime | OTP | 27 | GenServer, Supervisor, Port primitives |
| Web framework | Phoenix | 1.7+ | PubSub, LiveView, channels |
| UI framework | Phoenix LiveView | 1.0+ | Push-based, no polling, no React SPA |
| Domain layer | Ash Framework | 3.x | Declarative resources, policies, calculations |
| Persistence | AshPostgres | 2.x | Ash + Ecto + PostgreSQL |
| Auth | AshAuthentication | 4.x | First-class auth resource, not bolted on |
| API | AshJsonApi | 1.x | Auto-generated JSON:API from Ash resources |
| Jobs | Oban | 2.18+ | Durable PostgreSQL-backed job queue |
| Encryption | Cloak + Cloak.Ecto | 1.x | Field-level AES-256-GCM |
| JWT | Joken | 2.6+ | Per-run short-lived agent tokens |
| Rate limiting | Hammer | 7.x | In-process ETS, no Redis dependency |
| HTTP client | Finch | 0.19+ | Connection pooling, telemetry |
| Audit trail | AshPaperTrail | 0.1+ | Automatic change tracking on all resources |
| Telemetry | OpenTelemetry | 1.4+ | Distributed tracing |

### Infrastructure
| Component | Technology | Notes |
|---|---|---|
| Database | PostgreSQL 17 | Required (no embedded mode) |
| Deployment | Fly.io / Docker | Multi-stage Dockerfile, single binary |
| Clustering | libcluster | DNS-based, for multi-node PubSub |
| Monitoring | LiveDashboard + Oban.Web | Embedded ops dashboard |
| Error tracking | Sentry | Optional, via sentry-elixir |

### Frontend
| Component | Technology | Notes |
|---|---|---|
| HTML | Phoenix HEEx | Server-rendered |
| Interactivity | LiveView | Real-time, no polling |
| Minimal JS | Alpine.js | Dropdowns, tooltips only |
| CSS | Tailwind CSS 4 | Utility classes, CSS variables |
| Charts | Chart.js | Budget gauges, cost graphs |
| Icons | Heroicons | Consistent icon set |

---

## 3. APPLICATION ARCHITECTURE

### Umbrella Structure
```
paperclipex/                          # Umbrella root
├── apps/
│   ├── paperclipex_core/             # Domain logic only
│   │   ├── lib/paperclipex_core/
│   │   │   ├── accounts/             # User, CompanyMembership
│   │   │   ├── companies/            # Company, CompanyTemplate
│   │   │   ├── agents/               # Agent, AgentApiKey
│   │   │   ├── issues/               # Issue, IssueComment
│   │   │   ├── goals/                # Goal
│   │   │   ├── projects/             # Project
│   │   │   ├── approvals/            # Approval
│   │   │   ├── runs/                 # HeartbeatRun
│   │   │   ├── secrets/              # Secret
│   │   │   ├── activity/             # ActivityLog
│   │   │   ├── adapters/             # Behaviour + all adapter modules
│   │   │   ├── vault.ex              # Cloak vault
│   │   │   └── repo.ex               # AshPostgres.Repo
│   │   └── test/
│   │
│   ├── paperclipex_web/              # HTTP + LiveView + REST API
│   │   ├── lib/paperclipex_web/
│   │   │   ├── live/                 # All LiveView modules
│   │   │   ├── plugs/                # Auth, rate limit, tenant
│   │   │   ├── router.ex             # Phoenix router
│   │   │   ├── endpoint.ex
│   │   │   └── telemetry.ex
│   │   └── test/
│   │
│   └── paperclipex_workers/          # Oban workers only
│       ├── lib/paperclipex_workers/
│       │   ├── heartbeat_worker.ex
│       │   ├── approval_worker.ex
│       │   ├── budget_reset_worker.ex
│       │   ├── notification_worker.ex
│       │   └── budget_middleware.ex
│       └── test/
│
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── test.exs
│   ├── prod.exs
│   └── runtime.exs                   # All env var config lives here
└── rel/
    └── env.sh.eex
```

### Dependency Direction
```
paperclipex_web → paperclipex_core
paperclipex_workers → paperclipex_core
paperclipex_web ✗ paperclipex_workers (workers must not import web)
paperclipex_core ✗ paperclipex_web (domain must not import web)
```

---

## 4. DOMAIN MODEL

### Entity Relationship

```
User ─────── CompanyMembership ─── Company
                                      │
                    ┌─────────────────┤
                    │                 │
                  Goal            Project
                    │                 │
                    └──── Issue ──────┘
                            │
                         Agent (assignee)
                            │
                    ┌───────┴────────┐
                    │                │
               HeartbeatRun    Approval
                    │
               ActivityLog (linked via run_id)
```

### Multi-tenancy Model
- All resources (except User, CompanyMembership) are scoped to `company_id`
- Ash multi-tenancy strategy: `:attribute` (row-level, single schema)
- Every Ash query automatically filters by `company_id` from actor context
- Cross-company access is architecturally impossible at the query layer

### Agent Org Chart
```
CEO (no parent_agent_id)
  ├── CTO
  │     ├── Senior Coder
  │     └── QA Engineer
  ├── CMO
  │     ├── Content Writer
  │     └── SEO Analyst
  └── COO
        └── Operations Manager
```
- Strict tree: every agent reports to exactly one manager
- Max depth: configurable (default: 10)
- CEO agent is created automatically on company creation
- CEO strategy requires board approval before CEO begins work

---

## 5. HEARTBEAT PROTOCOL SPECIFICATION

The heartbeat is the core execution primitive. This is the precise contract.

### Heartbeat Trigger Types
| Type | When | Who |
|---|---|---|
| `:schedule` | Cron-based timer fires | Oban scheduler |
| `:assignment` | Issue assigned to agent | Issue.assign action → Oban enqueue |
| `:mention` | @agent_name in comment | IssueComment.create → Oban enqueue |
| `:manual` | Board operator clicks "Invoke" | Agent.invoke → Oban enqueue |
| `:approval_resolved` | Approval approved/rejected | Approval.decide → Oban enqueue |

### Heartbeat Execution Flow
```
1. Oban dequeues HeartbeatWorker job
2. BudgetMiddleware: check agent.budget_used_cents < monthly_budget_cents
   → If exhausted: cancel job, log ActivityLog, broadcast :budget_exhausted
3. Generate run_id (UUID v4)
4. Create HeartbeatRun record (status: :queued)
5. Issue Joken JWT: {sub: agent_id, jti: run_id, company_id, exp: +15min}
6. Call Agent.record_heartbeat_start (status: :running, last_heartbeat_at: now)
7. Broadcast {:run_started, ...} to PubSub "companies:{company_id}:runs"
8. Call adapter.execute(context) — this blocks until agent process finishes
   (Port for CLI, Finch for HTTP, Task for BeamNative)
9. Adapter streams stdout chunks → broadcast to "runs:{run_id}:stdout"
10. On adapter return:
    a. Update HeartbeatRun: status, tokens, cost, duration, stdout_log
    b. Atomically: agent.budget_used_cents += run.cost_cents (Ecto.Repo.transaction)
    c. Broadcast :spend_updated to "companies:{company_id}:costs"
    d. Call Agent.record_heartbeat_complete (status: :idle)
    e. Schedule next heartbeat if agent.heartbeat_schedule is set
    f. Broadcast {:run_completed, run} to "companies:{company_id}:runs"
11. On error:
    a. Call Agent.record_heartbeat_error (status: :error)
    b. HeartbeatRun status: :failed
    c. Oban retry with exponential backoff (attempt 2: +30s, attempt 3: +5min)
```

### Oban Job Uniqueness
```elixir
unique: [
  fields: [:args],
  keys: [:agent_id, :trigger],
  period: 60,     # deduplicate within 60 seconds
  states: [:available, :scheduled, :executing]
]
```

### JWT Specification
```
Algorithm: HS256
Secret: CLOAK_KEY (reused, distinct from session secret)
Claims:
  sub: agent_id (UUID string)
  jti: run_id (UUID string)
  iss: "paperclipex"
  aud: "agent"
  company_id: company_id (UUID string)
  iat: unix timestamp
  exp: iat + 900 (15 minutes)
```

---

## 6. ISSUE CHECKOUT SPECIFICATION

Atomic checkout is critical for correctness. This is the implementation contract.

```sql
-- Executed inside Ecto.Repo.transaction/2
BEGIN;

SELECT id, status, checked_out_at, checked_out_by_run_id
FROM issues
WHERE id = $1
  AND company_id = $2
FOR UPDATE SKIP LOCKED;

-- If no row returned: another agent holds the lock → return {:error, :conflict}
-- If row returned and checked_out_at is NOT NULL: already checked out → return {:error, :conflict}
-- If row returned and checked_out_at IS NULL: proceed

UPDATE issues
SET checked_out_at = NOW(),
    checked_out_by_run_id = $3
WHERE id = $1;

COMMIT;
```

Elixir:
```elixir
def checkout(%Issue{} = issue, run_id) do
  Repo.transaction(fn ->
    case Repo.one(checkout_query(issue.id, issue.company_id)) do
      nil ->
        Repo.rollback(:conflict)
      %Issue{checked_out_at: nil} ->
        issue
        |> Ecto.Changeset.change(checked_out_at: DateTime.utc_now(), checked_out_by_run_id: run_id)
        |> Repo.update!()
      _ ->
        Repo.rollback(:conflict)
    end
  end)
end
```

HTTP response: `409 Conflict` with body `{"error": "Issue is checked out by another agent"}`
Agents MUST NOT retry on 409 — pick a different issue.

---

## 7. ADAPTER SPECIFICATION

### Behaviour Contract
```elixir
defmodule PaperclipEx.Adapters.Behaviour do
  @type context :: %PaperclipEx.Adapters.AdapterContext{}
  @type result :: {:ok, %PaperclipEx.Adapters.RunResult{}} | {:error, term()}

  @callback execute(context) :: result
  @callback test_environment(config :: map()) :: {:ok, map()} | {:error, String.t()}
  @callback config_schema() :: NimbleOptions.schema()
  @callback adapter_type() :: atom()
end
```

### Environment Variables Injected into Agent Processes
```
PAPERCLIP_API_KEY     = <JWT token, 15min TTL>
PAPERCLIP_API_URL     = https://yourhost.fly.dev/api/v1
PAPERCLIP_AGENT_ID    = <uuid>
PAPERCLIP_RUN_ID      = <uuid>
PAPERCLIP_COMPANY_ID  = <uuid>
```

### Built-in Adapters
| Adapter | Type | Execution Model | Key Config |
|---|---|---|---|
| ClaudeLocal | :claude_local | Supervised Port (claude CLI) | model, working_dir, max_tokens |
| CodexLocal | :codex_local | Supervised Port (codex CLI) | model, working_dir |
| GeminiLocal | :gemini_local | Supervised Port (gemini CLI) | model, working_dir |
| Process | :process | Supervised Port (shell command) | command, args, working_dir |
| HTTP | :http | Finch HTTP POST | url, method, headers, timeout_ms |
| BeamNative | :beam_native | supervised Task | module, function |
| ObanWorker | :oban_worker | Oban job enqueue | worker_module, queue |

### BeamNative Adapter Contract
Any Elixir module can be an agent:
```elixir
defmodule MyApp.Agents.DataAnalyst do
  @behaviour PaperclipEx.Adapters.BeamNativeAgent

  @impl true
  def run(%PaperclipEx.Adapters.AdapterContext{} = ctx) do
    # ctx.api_token — use to call PaperclipEx REST API
    # ctx.config — adapter-specific config
    # Return RunResult
    {:ok, %PaperclipEx.Adapters.RunResult{status: :completed, ...}}
  end
end
```

---

## 8. API SPECIFICATION

### Base URL
`/api/v1/companies/:company_id/`

### Authentication
```
Authorization: Bearer <token>
```
Token types (checked in order):
1. Agent run JWT (issued per heartbeat, 15min TTL)
2. Agent long-lived API key (for HTTP adapter agents)
3. User session token (board operators)

Required header on all agent mutations:
```
X-Paperclip-Run-Id: <run_id>
```

### Error Response Shape
```json
{
  "errors": [{
    "status": "409",
    "title": "Conflict",
    "detail": "Issue is checked out by another agent"
  }]
}
```

### Status Codes
| Code | Meaning |
|---|---|
| 200 | Success |
| 201 | Created |
| 400 | Validation error |
| 401 | Missing or invalid token |
| 403 | Unauthorized (valid token, wrong permissions) |
| 404 | Not found (also returned for wrong company_id) |
| 409 | Conflict (checkout race) — do NOT retry |
| 422 | Invalid state transition |
| 429 | Rate limited (100 req / 5 min per agent) |
| 500 | Server error — comment on task and move on |

### Pagination
All list endpoints: cursor-based pagination
```
?page[size]=20&page[after]=<cursor>
```
Issues sorted by: priority DESC, inserted_at ASC
Others sorted by: inserted_at DESC

### Rate Limiting
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 94
X-RateLimit-Reset: 1743000000
```
Limit: 100 requests per 300 seconds per agent_id.
Board operators: 1000 requests per 300 seconds per user_id.

---

## 9. SECURITY SPECIFICATION

### Threat Model
| Threat | Mitigation |
|---|---|
| Agent reads another company's data | Ash multi-tenancy: company_id enforced at query level |
| Agent accesses another agent's secrets | Secret policy: agent_id scope check |
| Prompt injection via issue description | Input sanitisation before storage; never eval |
| Runaway agent spending | Budget middleware cancels Oban job |
| Stolen JWT | 15-minute TTL; jti validated against active HeartbeatRun |
| Stolen API key | Key stored as bcrypt hash; plaintext never persisted |
| Adapter config leaks credentials | adapter_config encrypted with Cloak AES-256-GCM |
| Audit log tampering | PostgreSQL trigger prevents UPDATE/DELETE on activity_logs |
| CSRF on LiveView forms | Phoenix built-in CSRF token (default on) |
| XSS via agent output | Markdown rendered with Earmark + sanitised with HtmlSanitizeEx |

### Encryption at Rest
- Secrets.value: `Cloak.Ecto.Binary` — AES-256-GCM
- Agent.adapter_config: `Cloak.Ecto.Map` — AES-256-GCM
- AgentApiKey.key: bcrypt hash (not Cloak — hashed, not reversible)

### Key Management
```
CLOAK_KEY=<base64-encoded 32-byte key>        # Primary encryption key
CLOAK_KEY_RETIRED=<base64-encoded 32-byte key> # Previous key for rotation
```
Keys are rotated by: setting CLOAK_KEY_RETIRED = old CLOAK_KEY, generating new CLOAK_KEY,
running `PaperclipEx.Release.rotate_keys/0` to re-encrypt all encrypted fields.

---

## 10. TESTING SPECIFICATION

### Test Pyramid
| Layer | Tool | Coverage Target |
|---|---|---|
| Domain (Ash resources, workers) | ExUnit + DataCase | 90% |
| Web (LiveView, plugs) | ExUnit + ConnCase + Wallaby | 80% |
| Adapters | ExUnit + Mox | 85% |
| State machines | StreamData (property tests) | All transitions |
| Concurrency | ExUnit async + Sandbox | Checkout race test |
| E2E | Wallaby (headless Chrome) | Happy paths only |

### Test Data
- Use Ash.Generator (NOT ExMachina or FactoryBot)
- Every test is isolated via Ecto.Adapters.SQL.Sandbox
- PubSub tested via Phoenix.PubSub.subscribe in test

### Critical Tests (non-negotiable)
1. Concurrent checkout: 10 tasks → exactly 1 succeeds, 9 get :conflict
2. Budget enforcement: heartbeat cancelled when budget_used >= monthly_budget
3. JWT expiry: requests with expired JWT return 401
4. Multi-tenancy isolation: agent from company A cannot read company B's issues
5. Audit log immutability: update raises exception
6. Secret encryption: raw DB query confirms value is binary (not plaintext)
7. Status machine: all invalid transitions raise Ash.Error.Invalid

---

## 11. PERFORMANCE SPECIFICATIONS

### Targets
| Metric | Target | Notes |
|---|---|---|
| Dashboard LiveView load | <200ms | p95, with 100 agents |
| API response (read) | <50ms | p95 |
| API response (write) | <100ms | p95 including audit log |
| Heartbeat job enqueue to start | <1s | Oban queue latency |
| Concurrent heartbeats | 50 | Oban :heartbeats queue concurrency |
| Agents per company | 100 | Soft limit, configurable |
| Companies per instance | 50 | Hard limit per Fly.io instance |
| Database connections | 20 | Ecto pool size |

### Database Indexes
All compound indexes defined in migrations:
- `(company_id, status)` on agents
- `(company_id, assignee_id, status)` on issues
- `(company_id, inserted_at)` on activity_logs (also partitioned by month)
- `(agent_id, status, started_at)` on heartbeat_runs
- `(next_heartbeat_at, status)` on agents (for scheduler query)

---

## 12. CONFIGURATION REFERENCE

### Required Environment Variables (Production)
```bash
DATABASE_URL=postgresql://user:pass@host:5432/paperclipex_prod
SECRET_KEY_BASE=<64+ char random string>
CLOAK_KEY=<base64 AES-256 key>
PHX_HOST=paperclipex.yourdomain.com
PORT=4000
PAPERCLIPEX_AUTH_MODE=authenticated_public
```

### Optional Environment Variables
```bash
CLOAK_KEY_RETIRED=<old key for rotation>
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
SENTRY_DSN=https://xxx@sentry.io/xxx
MAX_HEARTBEAT_CONCURRENCY=20
MAX_AGENTS_PER_COMPANY=100
HEARTBEAT_TIMEOUT_MS=600000
JWT_TTL_SECONDS=900
LOG_LEVEL=info
```

### Auth Modes
| Mode | Login Required | Network | Use Case |
|---|---|---|---|
| `local_trusted` | No | Loopback only | Solo dev/testing |
| `authenticated_private` | Yes | All interfaces | Team on Tailscale/VPN |
| `authenticated_public` | Yes | Public URL required | Cloud deployment |
