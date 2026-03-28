# PaperclipEx — Product Roadmap
## From Zero to Production-Grade AI Operating System

---

## VISION

PaperclipEx is the production-grade AI company operating system for teams who need their
agent workforce to actually work under load. Built on Elixir/Phoenix for fault tolerance,
real-time observability, and BEAM-native agent execution.

**Where Paperclip stops, PaperclipEx begins.**

---

## MILESTONE OVERVIEW

| Milestone | Name | Target | Status |
|---|---|---|---|
| M0 | Foundation | Week 2 | Planning |
| M1 | Core MVP | Week 5 | Planning |
| M2 | Production Ready | Week 8 | Planning |
| M3 | Full Feature Parity + | Week 11 | Planning |
| M4 | Platform (Clipmart) | Week 16 | Future |
| M5 | SaaS Launch | Week 20 | Future |

---

## M0 — FOUNDATION (Weeks 1–2)
### "The ground is solid"

**Goal:** Umbrella app compiles, database migrated, basic resources boot, tests pass.

**Deliverables:**
- Umbrella app (paperclipex_core, paperclipex_web, paperclipex_workers)
- All 14 database migrations applied cleanly
- User, Company, CompanyMembership Ash resources with basic auth
- `mix test` passes with 0 failures
- `mix ecto.reset` succeeds

**Definition of Done:**
- `iex -S mix` boots without errors
- `mix test` green
- Company can be created via Ash with correct slug generation
- User can authenticate (password strategy)

**Key decisions locked:**
- Umbrella structure (not monolith, not microservices)
- Ash Framework as domain layer (not raw Ecto)
- PostgreSQL only (no embedded DB mode)
- Oban for all async (no raw Task)

---

## M1 — CORE MVP (Weeks 3–5)
### "The engine runs"

**Goal:** A single agent can be created, approved, and run a heartbeat against a real issue.
The entire lifecycle from hire → approval → heartbeat → issue checkout → completion works.

**Deliverables:**
- All 10 Ash domain resources: Agent, Issue, Goal, Project, Approval, HeartbeatRun, Secret,
  ActivityLog, CompanyTemplate, IssueComment
- Agent status machine (all transitions, all policies)
- Issue atomic checkout (with concurrent checkout test passing)
- HeartbeatWorker (Oban): full lifecycle with MockAdapter
- BudgetMiddleware: cancels jobs at budget limit
- BudgetResetWorker: monthly cron reset
- ClaudeLocal adapter: spawns claude CLI, streams output
- Process adapter: arbitrary shell commands
- HTTP adapter: Finch-based with retry
- BeamNative adapter: first-class Elixir module execution
- JWT issuance and verification
- PubSub broadcasts for all lifecycle events
- Cloak encryption on secrets + adapter_config

**Definition of Done:**
- End-to-end test: create company → hire agent (approve) → assign issue → invoke heartbeat →
  agent checks out issue via API → updates status → heartbeat completes
- Concurrent checkout test: 10 goroutines → exactly 1 wins
- Budget middleware test: exhausted budget cancels Oban job
- ClaudeLocal test: test_environment/1 passes on dev machine
- Secret not stored in plaintext (raw DB query assertion)

**Metrics target:**
- Heartbeat job enqueue-to-start latency: <1s
- Checkout transaction: <10ms
- Budget check: <5ms (in-process via Oban middleware)

---

## M2 — PRODUCTION READY (Weeks 6–8)
### "This can go live"

**Goal:** Full security layer, REST API, and operational observability in place.
A real board operator can use this to manage real agents.

**Deliverables:**
- Complete authentication system (password + magic link + JWT + API keys)
- All plugs: Authenticate, VerifyRunJwt, RequireBoardOperator, RateLimit
- Complete REST API (all 25 endpoints) secured and rate-limited
- ActivityLog on every mutation (linked to run_id)
- Multi-tenancy isolation verified (cross-company access impossible)
- Telemetry events on all critical paths
- OpenTelemetry traces exported
- /metrics Prometheus endpoint
- /health endpoint
- LiveDashboard + Oban.Web mounted
- Structured JSON logging in production
- Sentry error tracking
- Docker multi-stage build (image <100MB)
- Fly.io deployment working (fly deploy succeeds)
- runtime.exs reads all config from environment

**Definition of Done:**
- Deployed to Fly.io: `fly deploy` succeeds
- /health returns 200 with all checks passing
- 50 concurrent heartbeats via load test without errors
- p95 API response time <100ms
- Multi-tenancy test: 404 when accessing another company's resource
- OWASP basic checklist: CSRF, XSS, injection mitigated
- Secret rotation tested end-to-end

**Security gates (non-negotiable before M2 sign-off):**
- [ ] Expired JWT returns 401 (test)
- [ ] Wrong company JWT returns 403 (test)
- [ ] Agent cannot read another agent's secret (test)
- [ ] ActivityLog UPDATE raises exception (test)
- [ ] adapter_config not in plaintext (test)
- [ ] Rate limiting activates at 100 requests (test)

---

## M3 — FULL FEATURE PARITY + (Weeks 9–11)
### "Better than Paperclip in every dimension"

**Goal:** Complete LiveView dashboard, company templates, CLI, and all features that
make PaperclipEx demonstrably superior to Paperclip.

**Deliverables:**
- All 15 LiveView pages (no polling anywhere — all PubSub)
- DashboardLive: real-time agent status grid, burn rate, pending approvals
- OrgChartLive: interactive agent org tree
- IssuesLive: live kanban board
- RunLive.Show: streaming terminal output
- CostsLive: agent spend charts with Chart.js
- ApprovalsLive: real-time approval queue
- ActivityLive: searchable audit log
- Full template system: export, import, seed templates
- 3 seed company templates (Dev Shop, Content Agency, Research Desk)
- CLI: all 6 commands, Burrito single-binary packaging
- Makefile: all targets
- CodexLocal + GeminiLocal adapters
- Full documentation suite

**Definition of Done:**
- Wallaby tests: all 7 LiveView integration tests pass
- Dashboard loads with 100 agents <200ms (p95)
- Template export: all secrets scrubbed
- Template import: org structure recreated correctly
- CLI: `paperclipex onboard` completes interactive setup
- All documentation files present and accurate

**Feature Differentiation Checklist vs Paperclip:**
- [ ] BeamNative adapter: any Elixir module is an agent (Paperclip cannot do this)
- [ ] Real-time dashboard: zero polling (Paperclip uses TanStack Query polling)
- [ ] Durable scheduling: Oban (Paperclip uses in-memory TS scheduler)
- [ ] Atomic budget enforcement: PostgreSQL transaction (Paperclip: synchronous TS check)
- [ ] Field-level encryption: Cloak (Paperclip: no encryption at rest)
- [ ] Fault tolerance: OTP supervisor tree per adapter (Paperclip: Express error handler)
- [ ] Built-in observability: Telemetry + OTEL (Paperclip: none)
- [ ] Immutable audit log: PG trigger (Paperclip: no immutability guarantee)
- [ ] Rate limiting in core: Hammer (Paperclip: "add at infrastructure level")

---

## M4 — PLATFORM (Weeks 12–16)
### "The ecosystem begins"

**Goal:** PaperclipEx becomes a platform, not just a product.
Clipmart launches. Multi-node clustering. Agent memory.

**Deliverables:**

**Clipmart (Template Marketplace):**
- Public template search and browse (by category, rating, downloads)
- Template versioning
- Template rating and reviews
- One-click import into running instance
- Publisher profiles (author attribution)
- Curated template collections

**Multi-node Clustering:**
- libcluster via Fly.io private networking
- Distributed PubSub across nodes (Phoenix.PubSub with PG adapter)
- Oban Pro for distributed queues (or pg_advisory_lock coordination)
- Consistent hashing for agent-to-node affinity
- Target: 500 concurrent agents across 3 nodes

**Agent Memory (PGVECTOR):**
- Semantic memory store per agent
- Agents can store/retrieve memory via REST API
- Memory scoped to agent + company
- Vector similarity search for relevant past context
- Memory TTL + capacity limits

**Webhook Notifications:**
- Resend email: approval requests, budget alerts, agent errors
- Slack webhook: configurable company-level notifications
- Discord webhook: same as Slack
- Notification preferences per board operator

**Definition of Done:**
- Clipmart: 10 public templates browseable without login
- Multi-node: 2 Fly.io machines, PubSub messages route correctly
- Agent memory: agent can store and retrieve 10 memory entries via API
- Webhooks: Slack notification received on approval request

---

## M5 — SAAS LAUNCH (Weeks 17–20)
### "Money comes in"

**Goal:** Self-serve SaaS with Stripe billing. First paying customer.

**Deliverables:**

**Self-Serve Signup:**
- Public registration (email + password)
- Email verification (Resend)
- Onboarding wizard: company setup, first agent hire, first heartbeat
- Free tier: 1 company, 3 agents, 100 heartbeats/month

**Stripe Billing:**
- Stripe Checkout for plan upgrade
- Stripe Webhooks for subscription events
- Metered billing based on heartbeat count + agent count
- Usage dashboard (heartbeats used, cost accrued)
- Invoice download

**Plans:**
| Plan | Price | Companies | Agents | Heartbeats/mo | Storage |
|---|---|---|---|---|---|
| Free | £0 | 1 | 3 | 100 | 1GB |
| Indie | £49/mo | 1 | 10 | 1,000 | 5GB |
| Team | £149/mo | 5 | 50 | 10,000 | 20GB |
| Scale | £299/mo | Unlimited | 200 | 100,000 | 100GB |
| Enterprise | Custom | Unlimited | Unlimited | Unlimited | Unlimited |

**SaaS Infrastructure:**
- Fly.io: 3 web machines (auto-scaled)
- Fly.io Postgres: dedicated cluster
- Fly.io Object Storage: log/template storage
- CDN: assets via Cloudflare
- Status page: Better Uptime

**Definition of Done:**
- First paying customer completes checkout
- Stripe subscription webhook updates plan in database
- Free tier enforced (heartbeat count blocked at limit)
- Stripe invoice downloadable
- Support email responding within 24h

---

## TECHNICAL DEBT REGISTER

Items to address before each milestone sign-off:

**Pre-M2:**
- [ ] All Ash actions return typed errors (no raw `{:error, "string"}`)
- [ ] No raw Ecto queries outside of Ash (except advisory lock in checkout)
- [ ] All test factories use Ash.Generator (remove any direct Repo.insert)
- [ ] Credo: zero warnings on strict mode

**Pre-M3:**
- [ ] All LiveView handle_info clauses have catch-all for unexpected messages
- [ ] No assigns updated in mount after subscribe (race condition)
- [ ] All PubSub broadcasts use typed structs (not raw maps)
- [ ] Wallaby tests run in CI without flakiness

**Pre-M4:**
- [ ] Database query count profiled for all dashboard queries
- [ ] N+1 queries eliminated (use Ash load with eager_load)
- [ ] ActivityLog partitioned by month (migration for existing data)
- [ ] Secret rotation tested with CLOAK_KEY_RETIRED path

---

## COMPETITIVE POSITIONING TIMELINE

| Month | PaperclipEx | Paperclip |
|---|---|---|
| Month 1 | M0: Foundation complete | 32k+ stars, Clipmart announced |
| Month 2 | M1: Core MVP, heartbeat engine | Clipmart beta |
| Month 3 | M2: Production-ready, deployed | Potential Node cluster support |
| Month 4 | M3: Full parity + LiveView, BeamNative | Clipmart public |
| Month 5 | M4: Clipmart, clustering, memory | Community adapters growing |
| Month 6 | M5: SaaS launch, first revenue | Enterprise deals |

**Our moat:** The BEAM runtime is not something Paperclip can retrofit. Their architecture
is fundamentally Node.js. To get true process-level isolation, durable scheduling, and
fault-tolerant supervisors, they would need to rewrite. We start with these properties.

---

## SUCCESS METRICS

### M3 (Internal)
- [ ] 50 concurrent heartbeats, zero failures
- [ ] Dashboard p95 <200ms with 100 agents
- [ ] Test coverage: core 90%, web 80%, adapters 85%
- [ ] Zero critical security findings
- [ ] All Credo warnings resolved

### M4 (Community)
- [ ] 1,000 GitHub stars
- [ ] 5 community-contributed adapters
- [ ] 20 templates on Clipmart
- [ ] 100 active instances (measured by telemetry opt-in)

### M5 (Revenue)
- [ ] £5,000 MRR within 60 days of launch
- [ ] 10 paying customers
- [ ] NPS > 60
- [ ] <2% monthly churn

---

## RISK REGISTER

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Paperclip ships clustering before M4 | Medium | Medium | BeamNative adapter is our moat regardless |
| Clipmart ecosystem grows too fast to compete | Low | High | Build Clipmart parity in M4, focus on quality |
| Ash Framework breaking change | Low | High | Pin minor version, test on upgrade |
| Oban licensing change (Pro) | Low | Medium | Oban CE is MIT, avoid Oban Pro dependencies |
| Node.js-first agent ecosystem (adapters) | High | Medium | HTTP adapter bridges all JS tools; BeamNative for Elixir-native |
| Solo founder bandwidth | High | High | Strict sprint discipline, no scope creep before M3 |

---

## RELEASE NAMING

| Version | Milestone | Name |
|---|---|---|
| 0.1.0 | M0 | "Ignition" |
| 0.2.0 | M1 | "Heartbeat" |
| 0.3.0 | M2 | "Hardened" |
| 1.0.0 | M3 | "Conductor" |
| 1.1.0 | M4 | "Platform" |
| 2.0.0 | M5 | "Commercial" |
