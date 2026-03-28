# PaperclipEx — TODO
## Complete Implementation Checklist

Status legend: [ ] Not started | [~] In progress | [x] Done | [!] Blocked

---

## SPRINT 1 — Foundation (Weeks 1–2)

### Project Setup
- [ ] Create umbrella app: `mix new paperclipex --umbrella`
- [ ] Create paperclipex_core: `cd apps && mix new paperclipex_core`
- [ ] Create paperclipex_web: `mix phx.new paperclipex_web --no-ecto`
- [ ] Create paperclipex_workers: `cd apps && mix new paperclipex_workers`
- [ ] Configure umbrella mix.exs with shared deps
- [ ] Add all dependencies (see SPECS.md section 2)
- [ ] Run `mix deps.get` and verify clean compile
- [ ] Configure Repo in paperclipex_core (AshPostgres.Repo)
- [ ] Configure PubSub in paperclipex_web application.ex
- [ ] Configure Oban in paperclipex_workers application.ex
- [ ] Set up config/ hierarchy (config.exs, dev.exs, test.exs, prod.exs, runtime.exs)
- [ ] Configure Cloak vault (paperclipex_core/lib/paperclipex_core/vault.ex)
- [ ] Set up test helpers (DataCase, ConnCase, ChannelCase)
- [ ] Configure Ecto.Adapters.SQL.Sandbox for tests
- [ ] Write test: application boots cleanly

### Database Migrations
- [ ] Migration 001: users table
- [ ] Migration 002: companies table
- [ ] Migration 003: company_memberships table
- [ ] Migration 004: agents table (with Cloak binary column)
- [ ] Migration 005: agent_api_keys table
- [ ] Migration 006: goals table (self-referential)
- [ ] Migration 007: projects table
- [ ] Migration 008: issues table (self-referential, advisory lock support)
- [ ] Migration 009: issue_comments table
- [ ] Migration 010: approvals table
- [ ] Migration 011: heartbeat_runs table
- [ ] Migration 012: secrets table (with Cloak binary column)
- [ ] Migration 013: activity_logs table + immutability trigger
- [ ] Migration 014: company_templates table
- [ ] Add all indexes (see SPECS.md section 11)
- [ ] Test: `mix ecto.reset` passes cleanly
- [ ] Test: all FK constraints enforced
- [ ] Test: activity_log UPDATE trigger raises exception

### Core Ash Resources — Accounts Domain
- [ ] User resource (AshAuthentication: password + magic link)
- [ ] CompanyMembership resource (join table with role)
- [ ] Company resource (multi-tenant root, all calculations)
- [ ] Company.create action with slug generation
- [ ] Company.archive action with validation (no running agents)
- [ ] Company policies (owner/admin vs viewer)
- [ ] Test: User.create/1
- [ ] Test: Company.create slug generation
- [ ] Test: Company.archive fails with running agents
- [ ] Test: viewer cannot call Company.update

---

## SPRINT 2 — Domain Resources (Week 3)

### Agent Resource
- [ ] Agent resource with all attributes
- [ ] Status machine (all 12 transitions, validation)
- [ ] Cloak.Ecto.Map for adapter_config field
- [ ] Agent relationships (company, manager, subordinates, issues, runs)
- [ ] Agent.hire action (creates approval, sets pending_approval)
- [ ] Agent.activate action (board only, after approval)
- [ ] Agent.pause / resume / terminate actions (board only)
- [ ] Agent.invoke action (enqueues HeartbeatWorker)
- [ ] Agent.record_heartbeat_start / complete / error (system)
- [ ] Agent.reset_monthly_budget (system, called by cron)
- [ ] Agent calculations: spend_percentage, budget_remaining, is_over_budget, depth_in_org
- [ ] Agent policies (board vs agent vs viewer)
- [ ] AshPaperTrail on Agent
- [ ] Test: all valid status transitions
- [ ] Test: all invalid status transitions raise Ash.Error.Invalid
- [ ] Test: adapter_config not stored in plaintext
- [ ] Test: agent cannot read another company's agents
- [ ] Test: spend_percentage calculation
- [ ] Test: invoke enqueues Oban job

### Issue Resource
- [ ] Issue resource with all attributes
- [ ] Status machine (backlog → todo → in_progress → in_review → done)
- [ ] Blocked state (in_progress ↔ blocked)
- [ ] Terminal states (done, cancelled — no further transitions)
- [ ] Issue.checkout action with PostgreSQL advisory lock
- [ ] Issue.release_checkout action
- [ ] Issue.transition action with policy validation
- [ ] Issue.assign action (board: anyone; agent: self only)
- [ ] Issue calculations: age_in_days, is_blocked, checkout_is_stale, goal_ancestry
- [ ] Issue policies
- [ ] IssueComment resource (belongs_to issue, author polymorphic)
- [ ] Test: all valid status transitions
- [ ] Test: checkout succeeds for unowned issue
- [ ] Test: checkout returns {:error, :conflict} for owned issue
- [ ] Test: CONCURRENCY — 10 tasks checkout same issue → exactly 1 succeeds
- [ ] Test: stale checkout detection
- [ ] Test: agent cannot checkout unassigned issue

### Goal & Project Resources
- [ ] Goal resource (self-referential hierarchy)
- [ ] Goal.achieve / abandon actions
- [ ] Project resource (linked to goal)
- [ ] Project status management
- [ ] Test: goal hierarchy loads correctly
- [ ] Test: issue.goal_ancestry calculation traverses correctly

### Approval Resource
- [ ] Approval resource with polymorphic subject
- [ ] Approval.request action (agents only)
- [ ] Approval.approve action (board only) → broadcasts PubSub
- [ ] Approval.reject action (board only) → broadcasts PubSub
- [ ] Approval resolution → enqueue HeartbeatWorker for requesting agent
- [ ] Approval policies
- [ ] Test: approval request creates approval with pending status
- [ ] Test: approve triggers agent activation (for hire approvals)
- [ ] Test: approval broadcasts to PubSub on decision
- [ ] Test: agent cannot approve/reject

---

## SPRINT 3 — Heartbeat Engine (Week 4)

### HeartbeatRun Resource
- [ ] HeartbeatRun resource with all attributes
- [ ] HeartbeatRun.create (system only)
- [ ] HeartbeatRun.mark_running / complete / fail / timeout
- [ ] HeartbeatRun policies (system + board only)
- [ ] Test: create sets correct initial state

### Oban Setup
- [ ] Configure Oban in config.exs with all queues:
  - :heartbeats (concurrency: 20)
  - :approvals (concurrency: 5)
  - :budgets (concurrency: 1)
  - :templates (concurrency: 3)
  - :notifications (concurrency: 10)
- [ ] Oban.Web mounted in router (board operator only)
- [ ] Oban telemetry integration

### BudgetMiddleware
- [ ] Implement Oban.Middleware behaviour
- [ ] before_process/2: load agent, check budget
- [ ] Cancel job if budget exhausted
- [ ] Log to ActivityLog on cancellation
- [ ] Broadcast :budget_exhausted to PubSub
- [ ] Test: job cancelled when budget_used >= monthly_budget
- [ ] Test: job proceeds when budget available
- [ ] Test: ActivityLog entry created on cancellation

### HeartbeatWorker
- [ ] Implement Oban.Worker (queue: :heartbeats, max_attempts: 3)
- [ ] Unique constraint (60s window per agent+trigger)
- [ ] JWT issuance via Joken
- [ ] Full execution flow (see SPECS.md section 5)
- [ ] PubSub broadcasts at each lifecycle stage
- [ ] Atomic budget update in Ecto.Repo.transaction
- [ ] Next heartbeat scheduling (if agent.heartbeat_schedule set)
- [ ] Error handling: update HeartbeatRun, set agent :error status
- [ ] Test: successful execution with MockAdapter
- [ ] Test: budget exhaustion cancels job
- [ ] Test: duplicate enqueue within 60s is deduplicated
- [ ] Test: JWT contains correct claims
- [ ] Test: budget atomically updated after completion
- [ ] Test: next heartbeat scheduled for recurring agents

### BudgetResetWorker (Cron)
- [ ] Oban cron job: runs at UTC 00:00 on day 1 of each month
- [ ] Resets budget_used_cents to 0 for ALL agents
- [ ] Logs reset to ActivityLog
- [ ] Test: reset clears budget for all agents in all companies

---

## SPRINT 4 — Adapter System (Week 5)

### Adapter Infrastructure
- [ ] AdapterContext struct
- [ ] RunResult struct
- [ ] Behaviour module with all callbacks
- [ ] Registry module (compile-time registration)
- [ ] MockAdapter for testing
- [ ] Test: Registry.lookup returns correct module
- [ ] Test: Registry.lookup returns error for unknown type
- [ ] Test: MockAdapter tracks invocations

### ClaudeLocal Adapter
- [ ] test_environment/1: verify claude CLI installed
- [ ] config_schema/0: NimbleOptions schema
- [ ] execute/1: full Port-based execution
- [ ] Environment variable injection
- [ ] Heartbeat prompt template builder
- [ ] stdout streaming to PubSub
- [ ] stream-json output parser (tokens, cost)
- [ ] Timeout enforcement with Port kill
- [ ] Test: test_environment returns error when claude not found
- [ ] Test: correct CLI command built
- [ ] Test: timeout kills Port
- [ ] Test: cost extracted from stream-json

### Process Adapter
- [ ] test_environment/1: verify command exists
- [ ] execute/1: Port-based with Paperclip env vars
- [ ] Exit code capture in session_state
- [ ] Test: correct env vars injected
- [ ] Test: exit code captured

### HTTP Adapter
- [ ] config_schema/0: url, method, headers, timeout_ms
- [ ] execute/1: Finch POST with retry (3 attempts, exponential backoff)
- [ ] Timeout enforcement
- [ ] RunResult parsing from response
- [ ] Test: correct JSON body sent
- [ ] Test: retry on 5xx
- [ ] Test: timeout returns {:error, :timeout}

### BeamNative Adapter (Differentiator)
- [ ] config_schema/0: module, function
- [ ] execute/1: supervised Task.yield with shutdown
- [ ] BeamNativeAgent behaviour for target modules
- [ ] Timeout via Task.yield/2 + Task.shutdown/2
- [ ] Test: correct module.function called
- [ ] Test: timeout terminates task
- [ ] Document: "How to write a BeamNative agent"

### CodexLocal & GeminiLocal Adapters
- [ ] CodexLocal: codex CLI wrapper
- [ ] GeminiLocal: gemini CLI wrapper
- [ ] Both follow same Port pattern as ClaudeLocal

---

## SPRINT 5 — Security Layer (Week 6)

### Authentication
- [ ] User resource with AshAuthentication
- [ ] Password strategy (email + bcrypt)
- [ ] Magic link strategy (email, 15min token)
- [ ] Authenticate plug: JWT → API key → session cookie
- [ ] VerifyRunJwt plug: full JWT validation
- [ ] RequireBoardOperator plug
- [ ] Rate limiting plug (Hammer): 100/5min per agent, 1000/5min per user
- [ ] Test: expired JWT returns 401
- [ ] Test: wrong company JWT returns 403
- [ ] Test: RequireBoardOperator rejects agent JWT
- [ ] Test: rate limiting activates after 100 requests

### Secrets & Encryption
- [ ] Cloak vault configuration
- [ ] Secret resource with Cloak.Ecto.Binary value_encrypted
- [ ] Secret.read_value action (agent-scoped policy)
- [ ] Secret.rotate action
- [ ] Template export: secret scrubbing confirmed
- [ ] Test: value not stored in plaintext
- [ ] Test: agent cannot read another agent's secret
- [ ] Test: rotation updates value and last_rotated_at

### ActivityLog
- [ ] ActivityLog resource (append-only, no update/delete actions)
- [ ] Ash change module: auto-log all resource mutations
- [ ] run_id linked from plug context
- [ ] PostgreSQL immutability trigger (verified in migration test)
- [ ] Test: every mutation creates ActivityLog entry
- [ ] Test: ActivityLog UPDATE raises exception
- [ ] Test: ActivityLog has correct run_id from request header

---

## SPRINT 6 — REST API (Week 7)

### Router & Plugs
- [ ] Phoenix router: API scope at /api/v1
- [ ] Pipeline: :api (authenticate, rate_limit, log_request)
- [ ] Pipeline: :board (authenticate, require_board_operator)
- [ ] All agent-facing endpoints under :api pipeline
- [ ] All board endpoints under :board pipeline
- [ ] Test: all routes reachable (router test)

### Agent-Facing Endpoints
- [ ] GET /companies/:id/agents/me
- [ ] GET /companies/:id/issues (with filter support)
- [ ] POST /companies/:id/issues (create)
- [ ] GET /companies/:id/issues/:id
- [ ] PATCH /companies/:id/issues/:id
- [ ] POST /companies/:id/issues/:id/checkout → 409 on conflict
- [ ] POST /companies/:id/issues/:id/release
- [ ] PATCH /companies/:id/issues/:id/transition
- [ ] POST /companies/:id/issues/:id/comments
- [ ] GET /companies/:id/goals
- [ ] GET /companies/:id/projects
- [ ] POST /companies/:id/approvals (request)
- [ ] GET /companies/:id/secrets/:name (own scope only)
- [ ] POST /runs/:run_id/heartbeat (progress update)

### Board-Facing Endpoints
- [ ] All agent CRUD (hire, update, pause, resume, terminate, invoke)
- [ ] GET/PATCH /approvals (approve, reject)
- [ ] GET /activity (paginated, filterable)
- [ ] GET /dashboard (aggregate metrics)
- [ ] All template endpoints (export, import, publish)

### API Tests
- [ ] Authentication: all endpoint auth scenarios
- [ ] Rate limiting: 429 after limit
- [ ] Checkout: 409 on conflict
- [ ] Activity log: entry per mutation
- [ ] Pagination: cursor works correctly
- [ ] Multi-tenancy: cannot access other company's resources

---

## SPRINT 7 — LiveView Dashboard (Weeks 8–9)

### Core LiveViews
- [ ] DashboardLive (main ops view)
  - [ ] mount/3: load agents, subscribe to all company topics
  - [ ] AgentStatusGrid component
  - [ ] ActivityFeed component
  - [ ] MetricsBar component
  - [ ] BurnRateGauge component
  - [ ] PendingApprovals component (with approve/reject)
  - [ ] handle_info for all PubSub topics
  - [ ] handle_event: approve, reject, invoke_agent
- [ ] OrgChartLive (interactive tree)
  - [ ] Recursive tree rendering
  - [ ] Status indicators on nodes
  - [ ] Click-to-agent-detail navigation
- [ ] AgentsLive (list + management)
  - [ ] Filter by status
  - [ ] Hire modal (form → Approval.request)
  - [ ] Quick actions (invoke, pause, terminate)
- [ ] AgentLive.Show (agent detail)
  - [ ] Status, budget gauge, run history
  - [ ] Subordinate list
  - [ ] Recent runs (last 10)
  - [ ] Invoke button
- [ ] IssuesLive (kanban board)
  - [ ] Columns: backlog, todo, in_progress, in_review, done
  - [ ] Live updates via PubSub
  - [ ] Drag-and-drop (Alpine.js)
  - [ ] Filter by assignee, priority, project
- [ ] IssueLive.Show
  - [ ] Status transition buttons
  - [ ] Comment thread
  - [ ] Activity timeline
  - [ ] Checkout status indicator
- [ ] ApprovalsLive
  - [ ] Pending queue with agent context
  - [ ] Approve/reject with note
  - [ ] Real-time badge count
- [ ] RunLive.Show (live terminal)
  - [ ] Streaming stdout
  - [ ] Token/cost tracker
  - [ ] Final summary
  - [ ] Elapsed timer
- [ ] CostsLive
  - [ ] Per-agent spend chart (Chart.js)
  - [ ] Company burn rate
  - [ ] Budget forecast
- [ ] SecretsLive (write-only)
- [ ] TemplatesLive (export/import)
- [ ] ActivityLive (audit log)
- [ ] SettingsLive (company config, members, auth mode)

### LiveView Tests (Wallaby)
- [ ] Dashboard: correct agent count shown
- [ ] Dashboard: PubSub status change updates card without reload
- [ ] Dashboard: approve updates approval list in real time
- [ ] Run viewer: stdout chunks appear in real time
- [ ] Run viewer: completed run shows cost summary
- [ ] Issues kanban: live update when issue status changes
- [ ] Approvals: badge count decrements on decision

---

## SPRINT 8 — Templates & Clipmart Foundation (Week 9)

### CompanyTemplate Resource
- [ ] CompanyTemplate resource
- [ ] Company.export_template action
  - [ ] Traverse org chart recursively
  - [ ] Scrub all secret values (set to null)
  - [ ] Preserve structure, roles, capabilities, adapter types
  - [ ] Include goal hierarchy and project structure
- [ ] Company.import_template action
  - [ ] Validate template_data schema
  - [ ] Create all agents with pending_approval status
  - [ ] Create goals, projects
  - [ ] Return list of secrets to configure (names only)
- [ ] Template categories: [:dev_shop, :content_agency, :research, :trading, :custom]
- [ ] Template search (by category, name, is_public)
- [ ] Download count tracking
- [ ] Test: export strips all secret values
- [ ] Test: import creates correct org structure
- [ ] Test: import requires secrets to be set before agents activate

### Seed Templates
- [ ] "Dev Shop" template: CEO → CTO → Coder + QA
- [ ] "Content Agency" template: CEO → CMO → Writer + SEO + Social
- [ ] "Research Desk" template: CEO → Analyst + Researcher + Reporter
- [ ] Each template: goals, projects, heartbeat schedules pre-configured

---

## SPRINT 9 — Observability & Production Hardening (Week 10)

### Telemetry
- [ ] All :telemetry.execute/3 events (see SPECS.md section 7)
- [ ] TelemetryMetricsPrometheus: /metrics endpoint
- [ ] All metrics defined (histogram, counter, gauge)
- [ ] LiveDashboard configured with Oban.Web panel
- [ ] Custom metrics page: heartbeat stats

### OpenTelemetry
- [ ] opentelemetry_phoenix: auto-instrument Phoenix
- [ ] opentelemetry_ecto: auto-instrument Ecto
- [ ] opentelemetry_oban: auto-instrument Oban
- [ ] OTLP exporter configured via env var
- [ ] Trace IDs in all log lines

### Structured Logging
- [ ] JSON log formatter in production
- [ ] agent_id, run_id, company_id in every log line (Logger.metadata)
- [ ] Log levels: debug (dev), info (prod)

### Error Tracking
- [ ] Sentry integration (sentry-elixir)
- [ ] SENTRY_DSN configurable via env
- [ ] Oban errors reported to Sentry

### Health Check
- [ ] GET /health endpoint
- [ ] Response: status, database, oban_queue_depth, beam_node, version

### Performance
- [ ] Load test: 50 concurrent heartbeats
- [ ] Load test: 100 concurrent API calls
- [ ] Profile: dashboard with 100 agents loads <200ms
- [ ] Verify: no N+1 queries in dashboard (check Ecto telemetry)

---

## SPRINT 10 — Deployment & CLI (Week 11)

### Docker
- [ ] Multi-stage Dockerfile
- [ ] .dockerignore
- [ ] Test: docker build succeeds
- [ ] Test: docker run boots and /health returns 200
- [ ] Final image size < 100MB

### Fly.io
- [ ] fly.toml (region: lhr)
- [ ] Postgres cluster configuration
- [ ] Auto-migrate on deploy (Release.migrate)
- [ ] Test: fly deploy succeeds
- [ ] Test: /health returns 200 on Fly

### Runtime Config
- [ ] runtime.exs reads all env vars (see SPECS.md section 12)
- [ ] All secrets from env (no config files in production)
- [ ] Auth mode configurable at runtime

### CLI
- [ ] `paperclipex onboard` mix task (interactive setup)
- [ ] `paperclipex run --agent <id> --watch` (stream heartbeat)
- [ ] `paperclipex invoke <agent_id>` (manual heartbeat)
- [ ] `paperclipex template export <company_id>` (export to JSON file)
- [ ] `paperclipex template import <file>` (import from JSON file)
- [ ] `paperclipex status` (show all agents + budget)
- [ ] Burrito packaging for single-binary distribution

### Makefile
- [ ] make build (docker build)
- [ ] make deploy (fly deploy)
- [ ] make migrate (run migrations via fly ssh)
- [ ] make seed (seed data)
- [ ] make console (IEx via fly ssh)
- [ ] make test (run full test suite)
- [ ] make coverage (coverage report)

---

## ONGOING — Documentation

- [ ] README.md: quickstart, feature overview, architecture diagram
- [ ] doc/DEVELOPING.md: local dev setup, test setup
- [ ] doc/ADAPTERS.md: how to create a custom adapter
- [ ] doc/TEMPLATES.md: how to create and publish templates
- [ ] doc/BEAM_NATIVE.md: BeamNative adapter guide (differentiator)
- [ ] doc/API.md: auto-generated from AshJsonApi (+ examples)
- [ ] doc/SECURITY.md: threat model, key rotation, secret management
- [ ] doc/DEPLOYMENT.md: Fly.io, Docker, bare metal guides
- [ ] CHANGELOG.md: semver-based changelog

---

## BACKLOG (Post-MVP)

- [ ] Clipmart: public template marketplace with search/ratings
- [ ] Multi-node clustering (libcluster DNS for Fly.io)
- [ ] Agent memory: PGVECTOR for semantic memory per agent
- [ ] Webhook notifications: Slack/Discord on approval request
- [ ] Email notifications: Resend integration
- [ ] Agent conversation history: full turn-by-turn log
- [ ] Cost projections: ML-based spend forecasting
- [ ] SaaS mode: self-serve signup, Stripe billing per company
- [ ] RBAC v2: custom roles with granular permissions
- [ ] SOC2 compliance mode: enhanced audit, retention policies
- [ ] Mobile PWA: approve/reject on mobile
