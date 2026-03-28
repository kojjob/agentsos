# PaperclipEx — Production-Ready Elixir/Phoenix Rebuild of Paperclip
## Full Architecture Evaluation, Feature Inventory & Build Plan

---

## Part 1: Paperclip Codebase Evaluation

### What Paperclip Is (Accurately)

Paperclip is a **control plane** for autonomous AI companies. It does not run agents — it
orchestrates them. Agents run externally (Claude Code CLI, Codex CLI, shell processes, HTTP
webhooks) and "phone home" to Paperclip's REST API during heartbeat execution windows.

**Core domain entities:**
- **Company** — top-level multi-tenant unit with a goal, org structure, and budget
- **Agent** — an AI employee with adapter type, role, reporting line, capabilities, budget, status
- **Issue** — the unit of work (backlog → todo → in_progress → in_review → done | cancelled)
- **Heartbeat** — a triggered execution window (schedule, assignment, mention, manual, approval)
- **Project** — grouping of issues aligned to a goal
- **Goal** — hierarchical objective that every task traces back to
- **Approval** — board gate required for agent hiring, CEO strategy, and board overrides
- **Activity** — immutable audit trail of every mutation
- **Cost** — per-agent token spend tracking against monthly budget limits
- **Secret** — scoped API keys and credentials for agents

### Their Tech Stack

| Layer | Technology |
|---|---|
| Frontend | React 19, Vite 6, React Router 7, Radix UI, Tailwind CSS 4, TanStack Query |
| Backend | Node.js 20+, Express.js 5, TypeScript |
| Database | PostgreSQL 17 (or embedded PGlite), Drizzle ORM |
| Auth | Better Auth (sessions + API keys) |
| Adapters | Claude Code, Codex, Gemini, Cursor, OpenCode, OpenClaw, Hermes, Process, HTTP |
| Scheduling | Application-level heartbeat scheduler |
| Package mgmt | pnpm 9 with workspaces |

### Architectural Weaknesses in Paperclip (Honest Assessment)

**1. Node.js Single-Threaded Agent Isolation**
Agent state management is entirely application-level. There is no runtime-level process
isolation. If one agent's execution blocks or crashes the scheduler loop, all agents are
affected. There is no supervisor tree to isolate failures.

**2. Application-Level Scheduling**
Heartbeat scheduling is implemented in TypeScript application code. There is no persistent,
durable job queue. If the server restarts mid-heartbeat, the run is lost. There is no dead
letter queue, no retry with backoff, no uniqueness guarantee.

**3. Budget Enforcement is Synchronous Application Logic**
Budget cap enforcement (`when used >= limit, stop`) is a runtime check in application code.
There is no atomic budget ledger. Concurrent heartbeats could theoretically race past the limit
before both checks resolve.

**4. No Real-Time Dashboard**
The React UI uses TanStack Query (polling) for state. There is no push-based real-time channel.
The "live" dashboard is actually a polling dashboard. WebSocket support is manual and
undocumented.

**5. Auth is Bolted On**
Better Auth is a third-party library configured during onboarding. Session management,
API key lifecycle, and token rotation are not first-class concerns in the domain model.

**6. No Rate Limiting in the Core**
The docs explicitly state: "No rate limiting is enforced in local deployments. Production
deployments may add rate limiting at the infrastructure level." This is a security gap for
any multi-tenant deployment.

**7. Adapter Isolation is Non-Existent**
Adapters spawn child processes or call external CLIs. If an adapter crashes, the error
propagates to the Express request handler. There is no process supervision. A broken adapter
config can take down the heartbeat loop.

**8. Security Concerns**
Cisco flagged OpenClaw (a primary agent Paperclip orchestrates) as a significant security
risk due to broad system permissions and susceptibility to prompt injection. The adapter
model inherits these risks without any sandboxing layer.

**9. No Observability**
Beyond the activity audit trail, there is no built-in telemetry, no trace IDs propagated
through agent runs, no structured logging, no metrics endpoint. Production debugging
requires reading raw logs.

**10. Clipmart Does Not Exist Yet**
The template marketplace is referenced but not shipped. The entire ecosystem moat they
are building is still vapourware.

---

## Part 2: PaperclipEx — The Elixir/Phoenix Version

### Why the BEAM Wins Here (Technical Precision)

| Problem | Node.js Paperclip | PaperclipEx on BEAM |
|---|---|---|
| Agent isolation | App-level state in TS objects | GenServer per agent — OS-level process isolation |
| Scheduler durability | In-memory TS scheduler | Oban — persistent, retryable, PostgreSQL-backed |
| Budget enforcement | Synchronous app-level check | Atomic PostgreSQL transaction via Ecto |
| Real-time dashboard | TanStack Query polling | Phoenix PubSub + LiveView — true push |
| Fault tolerance | Express error handler | OTP Supervisor tree — crash and restart per agent |
| Multi-tenancy | Application-level scoping | Ash multi-tenancy — schema or RLS level |
| Audit trail | Application-level logger | Ash paper_trail extension — built-in |
| Auth | Better Auth (3rd party) | Ash Authentication — first-class resource |
| Rate limiting | Infrastructure level only | Hammer or PlugAttack — in-process |
| Observability | None | Telemetry + OpenTelemetry + LiveDashboard |

---

## Part 3: Complete Feature Inventory to Build

### 3.1 Domain Layer (Ash Resources)

#### `Companies`
- [ ] `id`, `name`, `slug`, `goal`, `status` (active | suspended | archived)
- [ ] `monthly_budget_cents` — company-wide spend ceiling
- [ ] `mission` — long-form company mission statement
- [ ] Multi-tenant scoping via Ash `multitenancy :attribute, attribute: :company_id`
- [ ] `has_many :agents`, `has_many :projects`, `has_many :goals`, `has_many :issues`
- [ ] Actions: `create`, `update`, `archive`, `export_template`, `import_template`
- [ ] Calculations: `total_spend_this_month`, `agent_count`, `open_issue_count`, `burn_rate`

#### `Agents`
- [ ] `id`, `name`, `role_title`, `capabilities` (text), `status`, `adapter_type`, `adapter_config` (encrypted JSONB)
- [ ] `parent_agent_id` — strict tree hierarchy (manager/report relationship)
- [ ] `monthly_budget_cents` — per-agent spend cap
- [ ] `budget_used_cents` — running total, reset monthly via Oban cron
- [ ] `heartbeat_schedule` — cron expression or interval
- [ ] `last_heartbeat_at`, `next_heartbeat_at`
- [ ] Status enum: `pending_approval | active | idle | running | error | paused | terminated`
- [ ] Ash policy: `board operators can manage all; agents can read self and subordinates`
- [ ] Actions: `hire` (requires approval), `pause`, `resume`, `terminate`, `invoke` (manual heartbeat)
- [ ] Relationships: `has_many :issues`, `has_many :runs`, `belongs_to :manager`
- [ ] Calculations: `subordinate_count`, `spend_percentage`, `health_score`

#### `Issues` (Tasks)
- [ ] `id`, `title`, `description` (markdown), `status`, `priority`, `company_id`, `project_id`
- [ ] `assignee_id` — single agent, nullable
- [ ] `parent_issue_id` — hierarchical task tree
- [ ] `goal_id` — traces to company goal
- [ ] `checked_out_at`, `checked_out_by_run_id` — atomic checkout enforcement
- [ ] Status enum: `backlog | todo | in_progress | in_review | done | cancelled | blocked`
- [ ] Status transition validation — illegal transitions raise `{:error, :invalid_transition}`
- [ ] `409 Conflict` on concurrent checkout via database-level advisory lock
- [ ] Actions: `create`, `update`, `checkout` (atomic), `release`, `transition_status`, `assign`, `comment`
- [ ] Calculations: `age_in_days`, `is_overdue`, `goal_ancestry` (recursive)

#### `HeartbeatRuns`
- [ ] `id`, `agent_id`, `run_id` (UUID injected into agent env), `trigger_type`
- [ ] `trigger_type` enum: `schedule | assignment | mention | manual | approval_resolved`
- [ ] `status`: `queued | running | completed | failed | timed_out`
- [ ] `started_at`, `completed_at`, `duration_ms`
- [ ] `tokens_input`, `tokens_output`, `cost_cents`
- [ ] `stdout_log` — full captured output
- [ ] `session_state` — JSONB for adapter-specific state (e.g. Claude session ID)
- [ ] `error_message` — populated on failure
- [ ] Oban job per heartbeat — persistent, retryable with exponential backoff

#### `Approvals`
- [ ] `id`, `type` (hire_agent | ceo_strategy | board_override | custom)
- [ ] `requested_by_agent_id`, `subject` (polymorphic — agent, strategy, issue)
- [ ] `status`: `pending | approved | rejected`
- [ ] `decided_by_user_id`, `decided_at`, `decision_note`
- [ ] Phoenix PubSub broadcast on decision → triggers heartbeat on requesting agent
- [ ] Actions: `request`, `approve`, `reject`
- [ ] Board operators notified in real time via LiveView

#### `Goals`
- [ ] `id`, `title`, `description`, `parent_goal_id` (recursive hierarchy)
- [ ] `target_metric`, `target_value`, `current_value`
- [ ] `due_date`, `status` (active | achieved | abandoned)
- [ ] `has_many :projects`, `has_many :issues`

#### `Projects`
- [ ] `id`, `name`, `description`, `goal_id`, `status`
- [ ] `has_many :issues`

#### `Secrets`
- [ ] `id`, `name`, `value` (AES-256-GCM encrypted at rest via Cloak)
- [ ] `scope` (company | agent) — agents can only read their own secrets
- [ ] `last_rotated_at`, `expires_at`
- [ ] Never returned in API responses — write-only after creation
- [ ] Ash policy: agents can READ_ONLY their own scoped secrets via run JWT

#### `ActivityLog`
- [ ] `id`, `company_id`, `actor_type` (user | agent), `actor_id`
- [ ] `action`, `subject_type`, `subject_id`, `metadata` (JSONB)
- [ ] `run_id` — ties mutations to a specific heartbeat run
- [ ] Immutable — no update/delete actions
- [ ] Ash paper_trail extension on all core resources for automatic change tracking
- [ ] Append-only PostgreSQL partition by month for performance

#### `Costs`
- [ ] Derived from `HeartbeatRuns` — not a first-class stored entity
- [ ] Materialized view or Ash calculation aggregating spend per agent/company/period
- [ ] Monthly budget reset via Oban cron at UTC midnight on day 1

#### `Users` (Board Operators)
- [ ] `id`, `email`, `name`, `role` (owner | admin | viewer)
- [ ] Ash Authentication — magic link + password + API key
- [ ] Company membership via `CompanyMemberships` join resource

#### `AgentApiKeys`
- [ ] `id`, `agent_id`, `key_hash`, `last_used_at`, `expires_at`
- [ ] Short-lived JWT issued per heartbeat run (injected as `PAPERCLIP_API_KEY` env var)
- [ ] Long-lived static key for HTTP adapter agents

#### `CompanyTemplates`
- [ ] `id`, `name`, `description`, `author_id`, `category`
- [ ] `template_data` — JSONB blob: org structure + agent configs (secrets scrubbed)
- [ ] `is_public` — foundation for Clipmart
- [ ] Actions: `export_from_company`, `import_to_company`, `publish`, `clone`

---

### 3.2 Adapter System

Adapters in PaperclipEx are **Elixir behaviours** — not packages. Each adapter implements
a behaviour contract and is registered in the adapter registry.

```elixir
defmodule PaperclipEx.Adapters.Behaviour do
  @callback execute(context :: AdapterContext.t()) :: {:ok, RunResult.t()} | {:error, term()}
  @callback test_environment(config :: map()) :: {:ok, diagnostics :: map()} | {:error, term()}
  @callback parse_output(raw :: String.t()) :: {:ok, ParsedOutput.t()} | {:error, term()}
end
```

**Adapters to implement:**
- [ ] `ClaudeLocal` — spawn Claude Code CLI as supervised Port
- [ ] `CodexLocal` — spawn OpenAI Codex CLI as supervised Port  
- [ ] `GeminiLocal` — spawn Gemini CLI as supervised Port
- [ ] `Process` — arbitrary shell command via supervised Port
- [ ] `HTTP` — webhook delivery via Finch with retry
- [ ] `BeamNative` — first-class adapter for Elixir GenServers (unique differentiator)
- [ ] `ObanWorker` — Oban job as an agent adapter
- [ ] `PhoenixChannel` — agent communicates via Phoenix Channel (real-time bidirectional)

**Adapter Worker Supervision:**
```
AdapterSupervisor (DynamicSupervisor)
  └── AgentRunner (Task.Supervisor)
       └── Per-run supervised Task
```

Each heartbeat run is a supervised Task under a Task.Supervisor. If it crashes, the
supervisor records the failure in HeartbeatRuns and does NOT restart (one-for-one with
max_restarts: 0 for the run itself — Oban handles retry).

---

### 3.3 Heartbeat Scheduling (Oban)

```elixir
defmodule PaperclipEx.Workers.HeartbeatWorker do
  use Oban.Worker, queue: :heartbeats, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"agent_id" => agent_id, "trigger" => trigger}}) do
    # 1. Load agent + check budget
    # 2. Issue short-lived JWT run token
    # 3. Spawn adapter via AdapterSupervisor
    # 4. Capture result, record HeartbeatRun
    # 5. Broadcast run completion via PubSub
    # 6. Schedule next heartbeat if recurring
  end
end
```

**Oban queues:**
- `:heartbeats` — agent execution (concurrency: 20)
- `:approvals` — approval notifications (concurrency: 5)
- `:budgets` — monthly budget reset cron (concurrency: 1)
- `:templates` — import/export operations (concurrency: 3)
- `:notifications` — email/webhook notifications (concurrency: 10)

**Budget enforcement as Oban middleware:**
```elixir
defmodule PaperclipEx.Workers.BudgetMiddleware do
  @behaviour Oban.Middleware

  def before_process(job, next) do
    case check_budget(job.args["agent_id"]) do
      :ok -> next.(job)
      {:error, :budget_exhausted} -> {:cancel, "Budget exhausted for agent"}
    end
  end
end
```

---

### 3.4 Phoenix PubSub Topics

```
companies:{company_id}:agents         # Agent status changes
companies:{company_id}:issues         # Issue updates, assignments
companies:{company_id}:runs           # Live heartbeat run output streaming
companies:{company_id}:approvals      # New approval requests
companies:{company_id}:costs          # Budget updates, spend alerts
agents:{agent_id}:heartbeat           # Trigger heartbeat from UI
runs:{run_id}:stdout                  # Streaming stdout from adapter
```

---

### 3.5 LiveView UI Pages

All UI in Phoenix LiveView — zero React, no polling.

| Page | LiveView Module | Key Features |
|---|---|---|
| Dashboard | `DashboardLive` | Live agent status grid, burn rate, open issues, recent activity |
| Org Chart | `OrgChartLive` | Interactive tree with agent status indicators |
| Agents | `AgentsLive` | List, filter, hire, pause, invoke |
| Agent Detail | `AgentLive.Show` | Status, runs, budget gauge, subordinates, invoke |
| Issues | `IssuesLive` | Kanban board with live updates |
| Issue Detail | `IssueLive.Show` | Comments, activity timeline, status transitions |
| Goals | `GoalsLive` | Goal hierarchy, progress tracking |
| Projects | `ProjectsLive` | Issues grouped by project |
| Approvals | `ApprovalsLive` | Pending approvals with approve/reject actions |
| Run Viewer | `RunLive.Show` | Live streaming stdout, token usage, cost, trace |
| Costs | `CostsLive` | Agent spend charts, burn rate, budget forecasting |
| Secrets | `SecretsLive` | Write-only secret management |
| Templates | `TemplatesLive` | Export/import company templates |
| Settings | `SettingsLive` | Company config, members, adapter registry |
| Audit Log | `ActivityLive` | Searchable, filterable immutable log |

---

### 3.6 REST API (for Agents to Call In)

Agents interact with PaperclipEx via REST API during heartbeats. Exposed via `AshJsonApi`.

**Endpoints agents need:**
```
GET    /api/v1/companies/:id/agents/me              # Agent identity
GET    /api/v1/companies/:id/issues?filter=assigned # My assignments
POST   /api/v1/companies/:id/issues/:id/checkout    # Atomic checkout (advisory lock)
POST   /api/v1/companies/:id/issues/:id/release     # Release checkout
PATCH  /api/v1/companies/:id/issues/:id             # Update status, add comment
POST   /api/v1/companies/:id/issues/:id/comments    # Add comment / @mention
POST   /api/v1/companies/:id/approvals              # Request an approval
GET    /api/v1/companies/:id/goals                  # Goal hierarchy
GET    /api/v1/companies/:id/secrets/:name          # Read own scoped secret
POST   /api/v1/companies/:id/agents                 # Request to hire (board approval required)
POST   /api/v1/runs/:run_id/heartbeat               # Report heartbeat progress
```

**Authentication middleware:**
- Board operators: session cookie or long-lived API key
- Agent heartbeats: short-lived JWT (`PAPERCLIP_API_KEY`) valid for run duration only
- Static agent keys: for HTTP adapter agents that aren't JWT-invoked

**Rate limiting per agent (Hammer):**
```elixir
# 100 API calls per heartbeat window (5 min)
Hammer.check_rate("agent:#{agent_id}", 300_000, 100)
```

---

### 3.7 Security Improvements Over Paperclip

- [ ] **Secrets encrypted at rest** — Cloak library with AES-256-GCM, key rotation support
- [ ] **Short-lived JWTs per run** — JOKEN-issued, agent-scoped, 30-minute TTL
- [ ] **Prompt injection mitigation** — sanitise agent inputs before logging/storing
- [ ] **Adapter sandboxing** — Port-based adapter processes run with reduced OS permissions
- [ ] **Rate limiting** — Hammer, per-agent and per-company
- [ ] **Audit log integrity** — append-only table with PostgreSQL trigger preventing updates/deletes
- [ ] **Content Security Policy** — Phoenix built-in CSP headers
- [ ] **CSRF protection** — Phoenix built-in, enforced on all LiveView sessions
- [ ] **Secret scrubbing** — template export strips all secret values before serialisation
- [ ] **Company isolation** — Ash multi-tenancy enforced at query level, not just application code

---

### 3.8 Observability Stack

- [ ] **Telemetry** — `:telemetry` events on every heartbeat, API call, adapter execution
- [ ] **Phoenix LiveDashboard** — real-time BEAM metrics (processes, memory, message queues)
- [ ] **Oban Web** — job monitoring UI (embedded in LiveDashboard)
- [ ] **OpenTelemetry** — distributed traces via `opentelemetry_phoenix` + `opentelemetry_ecto`
- [ ] **Structured logging** — `Logger` with JSON formatter, run_id and agent_id in every log line
- [ ] **Error tracking** — Sentry integration via `sentry-elixir`
- [ ] **Health check endpoint** — `GET /health` returns DB status, queue depth, BEAM node info

---

### 3.9 Deployment

- [ ] **Single binary release** — `mix release` with embedded runtime
- [ ] **Docker image** — multi-stage build, ~50MB final image
- [ ] **Fly.io one-command deploy** — `fly launch` with `fly.toml`
- [ ] **Environment modes** — `local_trusted | authenticated_private | authenticated_public`
- [ ] **Database** — PostgreSQL 17 required (no embedded mode — production-first)
- [ ] **Migrations** — Ecto migrations, run on startup via Release.migrate()
- [ ] **Secrets management** — environment variables + Cloak vault (no .env files in production)
- [ ] **Clustering** — libcluster via DNS or Fly.io private network for multi-node PubSub

---

### 3.10 CLI (`paperclipex` Mix Task / Burrito Binary)

- [ ] `paperclipex onboard` — interactive setup (database, auth mode, first company)
- [ ] `paperclipex run --agent <id> --watch` — stream heartbeat output to terminal
- [ ] `paperclipex invoke <agent_id>` — trigger manual heartbeat
- [ ] `paperclipex template export <company_id>` — export company template
- [ ] `paperclipex template import <file>` — import company template
- [ ] `paperclipex status` — show all running agents + current budget burn

---

## Part 4: Build Sprints

### Sprint 1 — Foundation (Weeks 1–2)
- [ ] Mix umbrella app setup: `paperclipex_core`, `paperclipex_web`, `paperclipex_workers`
- [ ] Ash resources: Company, Agent, User, CompanyMembership
- [ ] Ash Authentication: magic link + password + API key
- [ ] Multi-tenancy via Ash `attribute` strategy
- [ ] Ecto migrations for all core tables
- [ ] Basic Phoenix router + plugs (auth, tenant resolution)

### Sprint 2 — Task & Issue System (Week 3)
- [ ] Ash resources: Issue, Project, Goal
- [ ] Issue status machine with transition validation
- [ ] Atomic checkout via PostgreSQL advisory lock
- [ ] Issue hierarchy (parent/child)
- [ ] AshJsonApi endpoints for agent-facing API
- [ ] ExUnit tests for all state transitions

### Sprint 3 — Heartbeat Engine (Week 4)
- [ ] Oban setup with all queues
- [ ] HeartbeatWorker with BudgetMiddleware
- [ ] HeartbeatRun resource
- [ ] Adapter behaviour + ClaudeLocal, Process, HTTP adapters
- [ ] AdapterSupervisor DynamicSupervisor
- [ ] JWT issuance per run (Joken)
- [ ] PubSub broadcasts on run events

### Sprint 4 — Governance & Approvals (Week 5)
- [ ] Approval resource with polymorphic subject
- [ ] Board approval gate policies on Agent hire
- [ ] Activity audit log + Ash paper_trail
- [ ] Secrets resource with Cloak encryption
- [ ] Rate limiting with Hammer

### Sprint 5 — LiveView Dashboard (Weeks 6–7)
- [ ] DashboardLive, OrgChartLive, AgentsLive, IssuesLive
- [ ] Live run viewer with streaming stdout
- [ ] ApprovalsLive with real-time approval flow
- [ ] CostsLive with Chart.js budget gauges
- [ ] ActivityLive audit log viewer
- [ ] SecretsLive write-only UI

### Sprint 6 — Adapters & Templates (Week 8)
- [ ] CodexLocal, GeminiLocal, BeamNative adapters
- [ ] CompanyTemplate resource
- [ ] Export/import with secret scrubbing
- [ ] Template categories and search

### Sprint 7 — Observability & Production Hardening (Week 9)
- [ ] OpenTelemetry integration
- [ ] LiveDashboard + Oban Web
- [ ] Sentry error tracking
- [ ] Docker multi-stage build
- [ ] Fly.io deploy config
- [ ] Load test heartbeat scheduler at 100 concurrent agents

### Sprint 8 — CLI & Docs (Week 10)
- [ ] Mix task CLI with Burrito packaging
- [ ] Getting started guide
- [ ] Adapter creation guide
- [ ] Template authoring guide
- [ ] API reference (auto-generated from AshJsonApi)

---

## Part 5: Key Technical Decisions & Rationale

| Decision | Choice | Reason |
|---|---|---|
| Framework | Elixir/Phoenix/LiveView/Ash | BEAM process model perfectly maps to agent worker model |
| Background jobs | Oban | Durable, PostgreSQL-backed, observable, production-tested |
| Multi-tenancy | Ash `:attribute` strategy | Row-level isolation, no schema duplication, simpler ops |
| Encryption | Cloak | Transparent field-level encryption, key rotation support |
| Auth | Ash Authentication | First-class resource, composable policies, not bolted on |
| Rate limiting | Hammer | In-process ETS-backed, no Redis dependency for basic use |
| CLI packaging | Burrito | Single binary, no Elixir runtime required on target machine |
| Real-time | Phoenix PubSub + LiveView | Zero polling, true push, no WebSocket boilerplate |
| Adapter isolation | Port + Task.Supervisor | OS-level process, supervisor restarts, BEAM-native |
| Testing | ExUnit + Wallaby + StreamData | Unit + integration + property-based coverage |

---

## Part 6: Naming & Positioning

**Product name:** `Beam` or `Forge` or `Conductor` (to be decided — not PaperclipEx)

**Positioning:** "The production-grade AI company operating system. Built on Elixir for teams
who need their agent workforce to actually scale."

**Differentiation vs Paperclip:**
- Fault-tolerant by design (not by configuration)
- Real-time dashboard (not polling)
- Durable job scheduling (not in-memory)
- Atomic budget enforcement (not application-level)
- Built-in observability (not an afterthought)
- BEAM-native agent adapter (unique capability)
- Production-first deployment (not local-first with production as afterthought)
