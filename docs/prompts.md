# PaperclipEx — Claude Code Prompts
## Production-Ready Agent Prompts for Every Build Phase

---

## HOW TO USE THIS FILE

These prompts are designed to be used with Claude Code (`claude`) in your terminal.
Each prompt is self-contained and scoped to a specific build task.
Paste any prompt directly into Claude Code, or use as a CLAUDE.md skill.

Convention:
- `[REPLACE_ME]` = substitute your actual value before running
- Prompts assume you are in the project root
- All prompts enforce TDD — write tests first

---

## GLOBAL PROJECT IDENTITY (CLAUDE.md)

```
You are building PaperclipEx — a production-grade, Elixir/Phoenix/Ash Framework
rebuild of the Paperclip AI agent orchestration platform.

STACK:
- Elixir 1.17+ / OTP 27
- Phoenix 1.7+ with LiveView
- Ash Framework 3.x with AshJsonApi, AshAuthentication, AshPaperTrail
- PostgreSQL 17
- Oban 2.x for background jobs
- Tailwind CSS 4 for styling
- Alpine.js for minimal JS interactions
- Cloak for field-level encryption
- Hammer for rate limiting
- Finch for HTTP client
- Joken for JWT

ARCHITECTURE:
- Umbrella app with 3 apps: paperclipex_core, paperclipex_web, paperclipex_workers
- Domain-Driven Design — domain logic in paperclipex_core
- All persistence via Ash resources with Ash.DataLayer.Ecto
- Multi-tenancy via Ash :attribute strategy on :company_id
- Event broadcasting via Phoenix.PubSub
- Background jobs via Oban (never spawn raw Tasks for business logic)

PRINCIPLES:
- Test-Driven Development — ExUnit tests before implementation
- Never mix domain logic into LiveView modules
- Never use raw Ecto queries — always go through Ash actions
- Ash policies enforce all authorization — never check permissions in LiveView or controllers
- All secrets encrypted at rest via Cloak before database insertion
- All mutations by agents must carry X-Paperclip-Run-Id header (logged to ActivityLog)
- Oban jobs for all async work — never use Task.async for business logic
- Pattern match on {:ok, result} and {:error, reason} — never rescue exceptions in business logic

TESTING:
- ExUnit with DataCase and ConnCase
- Ash.Generator for test data factories (not ExMachina)
- Wallaby for LiveView integration tests
- StreamData for property-based tests on state machines
- Minimum 90% coverage on core domain, 80% on web layer
```

---

## PHASE 1: PROJECT SCAFFOLDING

### Prompt 1.1 — Create Umbrella App

```
Create a new Elixir umbrella application called paperclipex with the following structure:

apps/
  paperclipex_core/     # Domain logic, Ash resources, Oban workers
  paperclipex_web/      # Phoenix, LiveView, AshJsonApi REST API
  paperclipex_workers/  # Oban worker modules only

Requirements:
1. Generate the umbrella with `mix new paperclipex --umbrella`
2. Add paperclipex_core with `mix phx.new` stripped of web layer (core only)
3. Add paperclipex_web as a full Phoenix 1.7 app pointing to paperclipex_core for schemas
4. Configure shared config in config/config.exs

Add these dependencies to the root mix.exs:
- ash ~> 3.0
- ash_postgres ~> 2.0
- ash_phoenix ~> 2.0
- ash_json_api ~> 1.0
- ash_authentication ~> 4.0
- ash_authentication_phoenix ~> 2.0
- ash_paper_trail ~> 0.1
- oban ~> 2.18
- cloak ~> 1.1
- cloak_ecto ~> 1.3
- joken ~> 2.6
- hammer ~> 7.0
- finch ~> 0.19
- sentry ~> 10.0
- opentelemetry ~> 1.4
- opentelemetry_phoenix ~> 1.2
- opentelemetry_ecto ~> 1.2

Create the Repo module in paperclipex_core with AshPostgres.Repo.
Configure PubSub in paperclipex_web application.ex.
Write a test to verify the application boots cleanly.
```

### Prompt 1.2 — Database Schema Setup

```
Set up the PostgreSQL database schema for PaperclipEx.

Create Ecto migrations for these tables (in order):

1. users
   - id (uuid primary key)
   - email (citext, unique, not null)
   - hashed_password (text)
   - name (text)
   - role (text, default: "member") -- owner | admin | member | viewer
   - confirmed_at (utc_datetime)
   - inserted_at, updated_at

2. companies
   - id (uuid primary key)
   - name (text, not null)
   - slug (text, unique, not null)
   - goal (text)
   - mission (text)
   - status (text, default: "active") -- active | suspended | archived
   - monthly_budget_cents (integer, default: 0)
   - inserted_at, updated_at

3. company_memberships
   - id (uuid primary key)
   - company_id (uuid, references companies)
   - user_id (uuid, references users)
   - role (text) -- owner | admin | member | viewer
   - unique index on (company_id, user_id)
   - inserted_at, updated_at

4. agents
   - id (uuid primary key)
   - company_id (uuid, references companies, not null)
   - name (text, not null)
   - role_title (text)
   - capabilities (text)
   - status (text, default: "pending_approval")
   - adapter_type (text, not null)
   - adapter_config_encrypted (binary) -- Cloak encrypted JSONB
   - parent_agent_id (uuid, references agents, nullable)
   - monthly_budget_cents (integer, default: 0)
   - budget_used_cents (integer, default: 0)
   - heartbeat_schedule (text) -- cron expression or nil
   - last_heartbeat_at (utc_datetime)
   - next_heartbeat_at (utc_datetime)
   - inserted_at, updated_at

5. agent_api_keys
   - id (uuid primary key)
   - agent_id (uuid, references agents)
   - key_hash (text, not null) -- bcrypt hash
   - label (text)
   - last_used_at (utc_datetime)
   - expires_at (utc_datetime)
   - inserted_at, updated_at

6. goals
   - id (uuid primary key)
   - company_id (uuid, references companies)
   - parent_goal_id (uuid, references goals, nullable)
   - title (text, not null)
   - description (text)
   - target_metric (text)
   - target_value (decimal)
   - current_value (decimal)
   - due_date (date)
   - status (text, default: "active") -- active | achieved | abandoned
   - inserted_at, updated_at

7. projects
   - id (uuid primary key)
   - company_id (uuid, references companies)
   - goal_id (uuid, references goals, nullable)
   - name (text, not null)
   - description (text)
   - status (text, default: "active")
   - inserted_at, updated_at

8. issues
   - id (uuid primary key)
   - company_id (uuid, references companies, not null)
   - project_id (uuid, references projects, nullable)
   - goal_id (uuid, references goals, nullable)
   - parent_issue_id (uuid, references issues, nullable)
   - assignee_id (uuid, references agents, nullable)
   - title (text, not null)
   - description (text)
   - status (text, default: "backlog")
   - priority (integer, default: 0) -- higher = more important
   - checked_out_at (utc_datetime)
   - checked_out_by_run_id (uuid)
   - inserted_at, updated_at

9. issue_comments
   - id (uuid primary key)
   - issue_id (uuid, references issues)
   - company_id (uuid, references companies)
   - author_type (text) -- user | agent
   - author_id (uuid)
   - body (text, not null)
   - run_id (uuid)
   - inserted_at, updated_at

10. approvals
    - id (uuid primary key)
    - company_id (uuid, references companies)
    - type (text) -- hire_agent | ceo_strategy | board_override | custom
    - requested_by_agent_id (uuid, references agents)
    - subject_type (text)
    - subject_id (uuid)
    - request_body (text)
    - status (text, default: "pending") -- pending | approved | rejected
    - decided_by_user_id (uuid, references users, nullable)
    - decided_at (utc_datetime)
    - decision_note (text)
    - inserted_at, updated_at

11. heartbeat_runs
    - id (uuid primary key)
    - agent_id (uuid, references agents)
    - company_id (uuid, references companies)
    - run_id (uuid, not null, unique) -- injected as PAPERCLIP_API_KEY sub
    - trigger_type (text) -- schedule | assignment | mention | manual | approval_resolved
    - status (text, default: "queued") -- queued | running | completed | failed | timed_out
    - tokens_input (integer)
    - tokens_output (integer)
    - cost_cents (integer)
    - stdout_log (text)
    - session_state (jsonb)
    - error_message (text)
    - started_at (utc_datetime)
    - completed_at (utc_datetime)
    - duration_ms (integer)
    - oban_job_id (integer)
    - inserted_at, updated_at

12. secrets
    - id (uuid primary key)
    - company_id (uuid, references companies)
    - agent_id (uuid, references agents, nullable) -- nil = company-scoped
    - name (text, not null)
    - value_encrypted (binary, not null) -- Cloak encrypted
    - last_rotated_at (utc_datetime)
    - expires_at (utc_datetime)
    - unique index on (company_id, name)
    - inserted_at, updated_at

13. activity_logs
    - id (uuid primary key, default: gen_random_uuid())
    - company_id (uuid, references companies)
    - actor_type (text) -- user | agent | system
    - actor_id (uuid)
    - action (text, not null)
    - subject_type (text)
    - subject_id (uuid)
    - metadata (jsonb, default: {})
    - run_id (uuid)
    - inserted_at (utc_datetime, not null)
    -- NO updated_at — immutable
    -- Add PostgreSQL trigger to prevent UPDATE/DELETE

14. company_templates
    - id (uuid primary key)
    - company_id (uuid, references companies, nullable) -- nil = system template
    - author_id (uuid, references users)
    - name (text, not null)
    - description (text)
    - category (text) -- dev_shop | content_agency | research | trading | custom
    - template_data (jsonb, not null) -- exported org with secrets scrubbed
    - is_public (boolean, default: false)
    - download_count (integer, default: 0)
    - inserted_at, updated_at

Create indexes:
- companies: slug
- agents: company_id, parent_agent_id, status, next_heartbeat_at
- issues: company_id, assignee_id, status, priority, parent_issue_id
- heartbeat_runs: agent_id, run_id, status, started_at
- activity_logs: company_id, actor_id, subject_id, inserted_at
- secrets: (company_id, name) unique

Write ExUnit tests to verify:
- All migrations run cleanly: mix ecto.reset passes
- All foreign key constraints are enforced
- The activity_log UPDATE trigger raises an exception
```

---

## PHASE 2: CORE ASH RESOURCES

### Prompt 2.1 — Company Resource

```
Create the Company Ash resource in paperclipex_core/lib/paperclipex_core/accounts/company.ex

Requirements:
1. Use Ash.Resource with AshPostgres.DataLayer
2. Multitenancy: NOT applied at company level (companies ARE the tenants)
3. Attributes: id, name, slug, goal, mission, status, monthly_budget_cents, timestamps
4. Status attribute: Ash.Type.Atom with constraints [one_of: [:active, :suspended, :archived]]
5. Slug: auto-generated from name on create via change, unique index enforced
6. Relationships:
   - has_many :agents, PaperclipEx.Core.Agents.Agent
   - has_many :projects, PaperclipEx.Core.Projects.Project
   - has_many :goals, PaperclipEx.Core.Goals.Goal
   - has_many :issues, PaperclipEx.Core.Issues.Issue
   - has_many :memberships, PaperclipEx.Core.Accounts.CompanyMembership
   - many_to_many :members, PaperclipEx.Core.Accounts.User, through: :memberships
7. Actions:
   - :create with accept [:name, :goal, :mission, :monthly_budget_cents]
     - change: auto-generate slug from name
     - change: create CEO agent placeholder (fire Oban job)
   - :read (default)
   - :update with accept [:name, :goal, :mission, :monthly_budget_cents, :status]
   - :archive (set status: :archived, validate no running agents)
   - :export_template (custom action returning CompanyTemplate struct)
8. Calculations:
   - :total_spend_this_month — sum of heartbeat_runs.cost_cents for current month
   - :agent_count — count of active agents
   - :open_issue_count — count of issues where status not in [:done, :cancelled]
   - :burn_rate_daily_cents — total_spend_this_month / days_elapsed
9. Policies:
   - board operators (role: owner | admin) can do anything
   - viewers can only read
   - agents cannot access Company resource at all
10. AshPaperTrail: track all changes

Write ExUnit tests covering:
- create/1 generates slug correctly (spaces → hyphens, downcased)
- create/1 fails if name is blank
- archive/1 fails if any agent has status :running
- total_spend_this_month calculation returns correct sum
- policy: viewer cannot call :update action
```

### Prompt 2.2 — Agent Resource with Status Machine

```
Create the Agent Ash resource in paperclipex_core/lib/paperclipex_core/agents/agent.ex

This is the most critical resource — model it carefully.

Requirements:
1. Attributes: id, company_id, name, role_title, capabilities, status, adapter_type,
   adapter_config (Cloak.Ecto.EncryptedMap), parent_agent_id, monthly_budget_cents,
   budget_used_cents, heartbeat_schedule, last_heartbeat_at, next_heartbeat_at, timestamps
2. Status machine — these are the ONLY valid transitions:
   - pending_approval → active (on approval)
   - pending_approval → terminated (on rejection)
   - active → idle (heartbeat completes)
   - active → running (heartbeat starts)
   - idle → running (heartbeat starts)
   - running → idle (heartbeat completes successfully)
   - running → error (heartbeat fails)
   - error → idle (manual or scheduled retry)
   - active | idle | error → paused (board action)
   - paused → active (board action)
   - active | idle | paused | error → terminated (board action)
   Any other transition must raise Ash.Error.Invalid
3. adapter_type: Ash.Type.Atom with values:
   [:claude_local, :codex_local, :gemini_local, :process, :http, :beam_native, :oban_worker]
4. Relationships:
   - belongs_to :company, Company
   - belongs_to :manager, Agent (self-referential, via parent_agent_id)
   - has_many :subordinates, Agent (foreign_key: :parent_agent_id)
   - has_many :assigned_issues, Issue (foreign_key: :assignee_id)
   - has_many :runs, HeartbeatRun
5. Actions:
   - :hire (create) — sets status: :pending_approval, fires ApprovalRequest
   - :read
   - :update_config — update adapter_config, capabilities (not status directly)
   - :activate — pending_approval → active (board only, after approval)
   - :pause — set status :paused (board only)
   - :resume — paused → active (board only)
   - :terminate — any → terminated (board only)
   - :invoke — trigger manual heartbeat (enqueue Oban HeartbeatWorker job)
   - :record_heartbeat_start — set status :running, last_heartbeat_at
   - :record_heartbeat_complete — set status :idle, update budget_used_cents
   - :record_heartbeat_error — set status :error, log error
   - :reset_monthly_budget — set budget_used_cents: 0 (system only, called by Oban cron)
6. Policies:
   - board operators: full access
   - agents: can read self and own subordinates only
   - agents: can call :record_heartbeat_start | :record_heartbeat_complete | :record_heartbeat_error on self only
   - agents: CANNOT call :hire, :terminate, :pause, :resume
   - viewers: read only
7. Calculations:
   - :spend_percentage — budget_used_cents / monthly_budget_cents * 100
   - :budget_remaining_cents — monthly_budget_cents - budget_used_cents
   - :is_over_budget — budget_used_cents >= monthly_budget_cents
   - :subordinate_count
   - :depth_in_org — recursive count of parent hops to CEO
8. Multitenancy: attribute :company_id
9. AshPaperTrail: track all changes

Write ExUnit tests covering:
- All valid status transitions succeed
- All invalid status transitions raise Ash.Error.Invalid
- invoke/1 enqueues an Oban job with correct args
- spend_percentage calculation is correct
- is_over_budget returns true when budget_used >= budget
- agent cannot read another company's agents (multitenancy isolation)
- Cloak encryption: adapter_config is not stored in plaintext (query raw DB)
```

### Prompt 2.3 — Issue Resource with Atomic Checkout

```
Create the Issue Ash resource with atomic checkout enforcement.

File: paperclipex_core/lib/paperclipex_core/issues/issue.ex

Requirements:
1. Attributes: id, company_id, project_id, goal_id, parent_issue_id, assignee_id,
   title, description, status, priority, checked_out_at, checked_out_by_run_id, timestamps
2. Status machine:
   - backlog → todo
   - todo → in_progress
   - in_progress → in_review
   - in_review → done
   - in_progress → blocked
   - blocked → in_progress
   - any non-terminal → cancelled
   Terminal: done, cancelled — no further transitions allowed
3. Priority: integer 0-100 (higher = more urgent), default 50
4. Actions:
   - :create — accept title, description, project_id, goal_id, parent_issue_id, priority
   - :read
   - :update — accept title, description, priority
   - :assign — set assignee_id (board can assign anyone; agents can only self-assign)
   - :transition — change status with validation
   - :checkout — ATOMIC checkout using PostgreSQL advisory lock
     - Must use Ecto.Repo.transaction with SELECT ... FOR UPDATE SKIP LOCKED
     - Set checked_out_at: DateTime.utc_now(), checked_out_by_run_id: run_id from context
     - Return {:error, :conflict} if already checked out (not raise)
     - This is how agents claim work — only one agent can hold a task
   - :release_checkout — clear checked_out_at and checked_out_by_run_id
   - :comment — create IssueComment (separate resource)
5. Multitenancy: attribute :company_id
6. Policies:
   - board operators: full access
   - agents: can read issues in their company
   - agents: can only checkout issues assigned to them
   - agents: can transition status of checked-out issues only
   - agents: cannot delete
7. Calculations:
   - :age_in_days — days since inserted_at
   - :is_blocked — status == :blocked
   - :checkout_is_stale — checked_out_at older than 2 hours (abandoned run)
   - :goal_ancestry — recursive load of parent goals up to company goal

Write ExUnit tests covering:
- checkout/1 succeeds for unowned issue
- checkout/1 returns {:error, :conflict} for already-checked-out issue
- Concurrent checkout test: spawn 10 tasks all trying to checkout same issue,
  verify exactly 1 succeeds and 9 get :conflict
- All valid status transitions
- Stale checkout detection (checked_out_at > 2 hours ago)
- Agent cannot checkout issue not assigned to them
```

### Prompt 2.4 — Heartbeat Run & Oban Worker

```
Create the HeartbeatRun resource and the Oban worker that drives agent execution.

Files:
- paperclipex_core/lib/paperclipex_core/runs/heartbeat_run.ex
- paperclipex_workers/lib/paperclipex_workers/heartbeat_worker.ex
- paperclipex_workers/lib/paperclipex_workers/budget_middleware.ex

HeartbeatRun resource:
1. Attributes: all fields from schema (see migration)
2. run_id is a UUID generated on job enqueue, injected into agent env as PAPERCLIP_API_KEY
3. Actions:
   - :create (system only — called by HeartbeatWorker before execution)
   - :read
   - :mark_running — set status :running, started_at
   - :complete — set status :completed, tokens, cost, duration, stdout_log
   - :fail — set status :failed, error_message
   - :timeout — set status :timed_out
4. Policies: system and board operators only — agents cannot read runs

HeartbeatWorker (Oban.Worker):
1. queue: :heartbeats, max_attempts: 3, unique: [period: 60] (prevent duplicate runs)
2. Args: %{"agent_id" => uuid, "trigger" => string, "company_id" => uuid}
3. perform/1 flow:
   a. Load agent (verify status is active | idle | error)
   b. Check budget via BudgetMiddleware (cancel job if exhausted)
   c. Generate run_id (UUID v4)
   d. Create HeartbeatRun record
   e. Issue short-lived JWT (15 min TTL, sub: agent_id, jti: run_id) via Joken
   f. Call adapter execute/1 with run context
   g. Broadcast run start to PubSub: "companies:{company_id}:runs"
   h. Stream stdout to PubSub: "runs:{run_id}:stdout" as adapter produces it
   i. On completion: update HeartbeatRun, update agent.budget_used_cents atomically
   j. Broadcast run completion
   k. Schedule next heartbeat if agent.heartbeat_schedule is set
   l. Return :ok or {:error, reason}

BudgetMiddleware:
1. Implement Oban.Middleware behaviour
2. before_process/2: load agent, check budget, cancel if exhausted
3. Log budget exhaustion to ActivityLog
4. Broadcast budget alert to PubSub

JWT specification:
- Algorithm: HS256
- Claims: sub (agent_id), jti (run_id), company_id, exp (15 min), iat
- Verify on every API request via plug
- Reject expired tokens with 401

Write ExUnit tests covering:
- HeartbeatWorker.perform/1 succeeds with mock adapter
- HeartbeatWorker.perform/1 cancels when budget exhausted
- HeartbeatWorker is idempotent (duplicate enqueue within 60s deduped by Oban unique)
- JWT is valid and contains correct claims
- JWT expires correctly (test with future expiry)
- Budget is atomically updated (use Ecto.Adapters.SQL.Sandbox for concurrent test)
```

---

## PHASE 3: ADAPTER SYSTEM

### Prompt 3.1 — Adapter Behaviour & Registry

```
Create the adapter behaviour and registry for PaperclipEx.

Files:
- paperclipex_core/lib/paperclipex_core/adapters/behaviour.ex
- paperclipex_core/lib/paperclipex_core/adapters/registry.ex
- paperclipex_core/lib/paperclipex_core/adapters/context.ex
- paperclipex_core/lib/paperclipex_core/adapters/run_result.ex

AdapterContext struct:
  %AdapterContext{
    agent_id: Ecto.UUID.t(),
    run_id: Ecto.UUID.t(),
    company_id: Ecto.UUID.t(),
    api_token: String.t(),         # short-lived JWT
    api_base_url: String.t(),      # "http://localhost:4000/api/v1"
    config: map(),                 # decrypted adapter_config
    working_dir: String.t(),       # agent's working directory
    timeout_ms: integer()          # default 600_000 (10 min)
  }

RunResult struct:
  %RunResult{
    status: :completed | :failed | :timed_out,
    stdout: String.t(),
    tokens_input: integer() | nil,
    tokens_output: integer() | nil,
    cost_cents: integer() | nil,
    session_state: map(),
    error_message: String.t() | nil,
    duration_ms: integer()
  }

Adapter behaviour (@callbacks):
  - execute(context :: AdapterContext.t()) :: {:ok, RunResult.t()} | {:error, term()}
  - test_environment(config :: map()) :: {:ok, map()} | {:error, String.t()}
  - config_schema() :: [Keyword.t()]  # returns NimbleOptions schema for config validation
  - adapter_type() :: atom()

Registry:
  - register/2 — register adapter module under type atom
  - lookup/1 — return adapter module for type, {:error, :unknown_adapter} if not found
  - list_adapters/0 — return all registered adapters with metadata
  - Use a module attribute + compile-time registration pattern (not ETS)

Create a MockAdapter for testing:
  - Implements Behaviour
  - execute/1 returns configurable RunResult
  - Tracks call count and args for assertions
  - Supports simulating delays and errors

Write ExUnit tests covering:
- Registry.lookup returns correct module for each registered type
- Registry.lookup returns {:error, :unknown_adapter} for unknown type
- MockAdapter execute/1 returns configured result
- MockAdapter tracks invocation correctly
- config_schema validation catches missing required keys
```

### Prompt 3.2 — ClaudeLocal Adapter

```
Create the ClaudeLocal adapter that runs Claude Code CLI as a supervised OS process.

File: paperclipex_core/lib/paperclipex_core/adapters/claude_local.ex

Requirements:
1. Implements Adapters.Behaviour
2. adapter_type/0 returns :claude_local
3. config_schema/0 returns NimbleOptions schema with:
   - model: string, required (e.g. "claude-opus-4-5")
   - working_dir: string, required
   - max_tokens: integer, default 32768
   - allowed_tools: list of strings, default []
4. execute/1:
   a. Validate claude CLI is installed via System.find_executable("claude")
   b. Build the heartbeat prompt from AdapterContext (see prompt template below)
   c. Set environment variables:
      - PAPERCLIP_API_KEY={context.api_token}
      - PAPERCLIP_API_URL={context.api_base_url}
      - PAPERCLIP_AGENT_ID={context.agent_id}
      - PAPERCLIP_RUN_ID={context.run_id}
      - PAPERCLIP_COMPANY_ID={context.company_id}
   d. Spawn Port with: claude --output-format stream-json --max-turns 50 {allowed_tools}
   e. Collect Port output chunks, broadcast each to PubSub "runs:{run_id}:stdout"
   f. Parse stream-json output to extract: input_tokens, output_tokens, cost
   g. Enforce timeout: kill Port after context.timeout_ms
   h. Return RunResult

Heartbeat prompt template (build from context):
"You are {agent.name}, {agent.role_title} at a company with mission: {company.goal}

Your capabilities: {agent.capabilities}

This is heartbeat run {run_id}. Use the Paperclip API to:
1. GET {api_base_url}/companies/{company_id}/agents/me — confirm your identity
2. GET {api_base_url}/companies/{company_id}/issues?filter[assignee_id]={agent_id}&filter[status]=todo — get your assignments
3. POST {api_base_url}/companies/{company_id}/issues/{id}/checkout — claim your next task
4. Do the work described in the issue
5. PATCH {api_base_url}/companies/{company_id}/issues/{id} — update status
6. POST {api_base_url}/companies/{company_id}/issues/{id}/comments — report completion

Always include header: X-Paperclip-Run-Id: {run_id} on all API calls.
When done, there is no need to say goodbye — just stop."

5. test_environment/1:
   - Check `claude --version` succeeds
   - Return {:ok, %{version: version_string}}
   - Return {:error, "claude CLI not found"} if missing

6. Port supervision:
   - Use Port.open with :exit_status and :stderr_to_stdout
   - Handle :EXIT message to detect premature termination
   - Broadcast :port_exited event to PubSub before returning

Write ExUnit tests:
- test_environment/1 returns error when claude not found
- execute/1 with MockPort builds correct CLI command
- Timeout enforcement kills Port after timeout_ms
- Cost extraction from stream-json output
- Environment variables are correctly set
```

### Prompt 3.3 — HTTP & Process Adapters

```
Create the HTTP adapter and Process adapter.

HTTP Adapter (paperclipex_core/lib/paperclipex_core/adapters/http.ex):
1. adapter_type: :http
2. config_schema: url (required), method (default POST), headers (map), timeout_ms
3. execute/1:
   - POST/GET to configured URL with JSON body containing AdapterContext
   - Use Finch for HTTP (not HTTPoison)
   - Retry up to 3 times with exponential backoff on 5xx
   - Parse response body as RunResult JSON
   - Respect timeout_ms
   - Return {:error, :timeout} on timeout
   - Log all HTTP calls to ActivityLog

Process Adapter (paperclipex_core/lib/paperclipex_core/adapters/process.ex):
1. adapter_type: :process
2. config_schema: command (required, string), args (list), working_dir, env_vars (map)
3. execute/1:
   - Spawn command as supervised Port
   - Inject Paperclip env vars (same as ClaudeLocal)
   - Collect stdout, broadcast to PubSub
   - Respect timeout
   - Return exit code in RunResult.session_state

BeamNative Adapter (paperclipex_core/lib/paperclipex_core/adapters/beam_native.ex):
1. adapter_type: :beam_native  ← UNIQUE DIFFERENTIATOR
2. config_schema: module (required, atom), function (required, atom)
3. execute/1:
   - Call Module.function(context) directly in a supervised Task
   - The called function receives AdapterContext and must return {:ok, RunResult.t()}
   - This allows any Elixir module to be an agent — no CLI, no HTTP
   - Timeout via Task.yield with shutdown
   - Perfect for Oban-based agents, internal data processors, etc.
4. This adapter is our key differentiator over Paperclip — document it thoroughly

Write ExUnit tests for all three adapters using mocked HTTP/Port/Task calls.
```

---

## PHASE 4: REST API

### Prompt 4.1 — AshJsonApi REST API for Agents

```
Create the REST API that agents call during heartbeats.

All endpoints require JWT authentication (issued per heartbeat run).
Mount under: /api/v1/companies/:company_id/

Implement these AshJsonApi routes in paperclipex_web/lib/paperclipex_web/router.ex:

GET    /agents/me                  → Agent.read (filter: id == token.sub)
GET    /agents                     → Agent.read (board only)
POST   /agents                     → Agent.hire
PATCH  /agents/:id/pause           → Agent.pause (board only)
PATCH  /agents/:id/resume          → Agent.resume (board only)
DELETE /agents/:id                 → Agent.terminate (board only)
POST   /agents/:id/invoke          → Agent.invoke (board + self)

GET    /issues                     → Issue.read (supports filters: status, assignee_id, priority)
POST   /issues                     → Issue.create
GET    /issues/:id                 → Issue.read (single)
PATCH  /issues/:id                 → Issue.update
POST   /issues/:id/checkout        → Issue.checkout (atomic)
POST   /issues/:id/release         → Issue.release_checkout
PATCH  /issues/:id/transition      → Issue.transition
POST   /issues/:id/comments        → IssueComment.create

GET    /goals                      → Goal.read
GET    /projects                   → Project.read

GET    /approvals                  → Approval.read (board only)
POST   /approvals                  → Approval.request (agents only)
PATCH  /approvals/:id/approve      → Approval.approve (board only)
PATCH  /approvals/:id/reject       → Approval.reject (board only)

GET    /secrets/:name              → Secret.read_value (agents: own scope only)

GET    /activity                   → ActivityLog.read (board only, paginated)
GET    /dashboard                  → aggregate dashboard metrics

POST   /runs/:run_id/heartbeat     → HeartbeatRun.progress update (streaming)

Requirements:
1. All routes protected by PaperclipEx.Web.Plugs.Authenticate
2. Company isolation enforced — 404 if company_id doesn't match token claim
3. X-Paperclip-Run-Id header must be present on all agent mutations
4. Rate limiting: 100 requests per 5-minute window per agent (Hammer)
5. Request logging: all mutations logged to ActivityLog with actor, action, subject
6. Response format: JSON:API spec (AshJsonApi handles this)
7. Pagination: cursor-based on all list endpoints

Write ExUnit + Wallaby tests covering:
- JWT authentication rejects expired tokens
- JWT authentication rejects wrong company
- Rate limiting kicks in after 100 requests
- Checkout returns 409 when already checked out
- Activity log entry created for every mutation
- Viewer role cannot call write endpoints
```

---

## PHASE 5: LIVEVIEW DASHBOARD

### Prompt 5.1 — Dashboard LiveView

```
Create the main DashboardLive module.

File: paperclipex_web/lib/paperclipex_web/live/dashboard_live.ex

This is the primary operator view — it must feel like a mission control center.

Requirements:
1. mount/3:
   - Load company with preloaded agents (limit: 20, sorted by status)
   - Load open issues count, running agents count, pending approvals count
   - Subscribe to PubSub topics:
     "companies:{company_id}:agents"
     "companies:{company_id}:runs"
     "companies:{company_id}:approvals"
     "companies:{company_id}:costs"
2. handle_info/2 for all PubSub events — update assigns without full reload
3. Components to render:
   - AgentStatusGrid: 2-column grid of agent cards showing:
     name, role, status (colored dot), current task, budget gauge
   - ActivityFeed: live scrolling feed of recent ActivityLog entries (last 20)
   - MetricsBar: total agents, running now, open issues, pending approvals, monthly spend
   - BurnRateGauge: company monthly spend vs budget (progress bar)
   - PendingApprovals: list of pending approvals with quick approve/reject buttons
4. handle_event/3:
   - "approve", %{"id" => id} → call Approval.approve, broadcast
   - "reject", %{"id" => id} → call Approval.reject, broadcast
   - "invoke_agent", %{"id" => id} → call Agent.invoke (enqueue heartbeat)
5. No polling — all updates via PubSub handle_info

Write Wallaby integration tests:
- Dashboard loads and shows correct agent count
- Approving an approval via button updates the list in real time
- Agent status change from PubSub updates the card without page reload
- Budget gauge shows correct percentage
```

### Prompt 5.2 — Live Run Viewer

```
Create the RunLive.Show LiveView for streaming heartbeat output.

File: paperclipex_web/lib/paperclipex_web/live/run_live/show.ex

This is the "terminal window" view — shows live stdout as an agent runs.

Requirements:
1. mount/3:
   - Load HeartbeatRun by run_id
   - Load associated agent
   - Subscribe to PubSub "runs:{run_id}:stdout"
   - Subscribe to PubSub "runs:{run_id}:completed"
   - If run already completed, show static transcript
2. handle_info/2:
   - {:stdout_chunk, chunk} → append to @transcript, push_event "scroll_to_bottom"
   - {:run_completed, run} → update assigns with final stats (tokens, cost, duration)
   - {:run_failed, reason} → show error state
3. Render:
   - Terminal-style stdout display (dark background, monospace, syntax highlighting)
   - Running header: agent name, trigger type, elapsed time (live timer via :timer.send_interval)
   - Cost tracker: live token count updating as chunks arrive
   - Final summary card: total tokens, cost in £/$/cents, duration
   - Issue changes made during run (loaded from ActivityLog by run_id)
4. Keyboard shortcut: press Escape to go back to agent detail

Implement the PubSub broadcast side in HeartbeatWorker:
  Phoenix.PubSub.broadcast(
    PaperclipEx.PubSub,
    "runs:#{run_id}:stdout",
    {:stdout_chunk, chunk}
  )

Write Wallaby tests:
- Run viewer shows "waiting" state for queued run
- Stdout chunks appear in real time
- Completed run shows final cost summary
- Elapsed timer updates every second
```

---

## PHASE 6: SECURITY & HARDENING

### Prompt 6.1 — Authentication & Authorization

```
Implement the complete authentication and authorization system.

Files:
- paperclipex_core/lib/paperclipex_core/accounts/user.ex (Ash resource)
- paperclipex_web/lib/paperclipex_web/plugs/authenticate.ex
- paperclipex_web/lib/paperclipex_web/plugs/verify_run_jwt.ex
- paperclipex_web/lib/paperclipex_web/plugs/require_board_operator.ex

User resource:
1. AshAuthentication strategies:
   - :password (email + password, bcrypt)
   - :magic_link (email-based, 15-min token)
2. Roles: [:owner, :admin, :member, :viewer]
3. Actions: register_with_password, sign_in_with_password, request_magic_link

Authenticate plug:
1. Check Authorization header for Bearer token
2. Try JWT verification first (agent run token)
3. Try API key lookup second (long-lived agent key)
4. Try session cookie third (board operator)
5. Set conn assigns: :current_actor (User or Agent struct), :actor_type, :company_id
6. Return 401 JSON if none match

VerifyRunJwt plug:
1. Parse JWT with Joken using HS256
2. Verify: exp not passed, sub is valid agent_id, company_id matches path param
3. Verify jti (run_id) is an active HeartbeatRun (not timed out or cancelled)
4. Set conn.assigns[:run_id] for ActivityLog

RequireBoardOperator plug:
1. Verify :actor_type == :user
2. Verify user has role :owner | :admin in company
3. Return 403 if not met

Write ExUnit tests:
- Authenticate plug extracts JWT correctly
- Authenticate plug rejects expired JWT with 401
- Authenticate plug rejects JWT for wrong company with 403
- RequireBoardOperator rejects agent JWTs with 403
- Verify all plug combinations for all endpoint types
```

### Prompt 6.2 — Secrets & Encryption

```
Implement the Secrets resource with Cloak field-level encryption.

Files:
- paperclipex_core/lib/paperclipex_core/vault.ex
- paperclipex_core/lib/paperclipex_core/secrets/secret.ex

Vault (Cloak.Vault):
1. Configure Cloak.AES.GCM as primary cipher
2. Key loaded from environment variable CLOAK_KEY (base64-encoded 256-bit key)
3. Key rotation: support CLOAK_KEY_RETIRED for rotating old keys
4. Provide Vault.generate_key/0 helper for setup

Secret resource:
1. value_encrypted: Cloak.Ecto.Binary type (auto-encrypt/decrypt)
2. adapter_config_encrypted on Agent: Cloak.Ecto.Map type
3. Actions:
   - :create — value never returned after creation
   - :read — return metadata only (name, scope, last_rotated_at), NEVER the value
   - :read_value — separate action, returns decrypted value, agent-only for own scope
   - :rotate — update value, set last_rotated_at
   - :delete
4. read_value policy:
   - Agents can only read secrets scoped to their agent_id or their company (no agent_id)
   - Board operators can read any secret in their company
5. API response: never include encrypted field in JSON responses

Write ExUnit tests:
- Secret value is not stored in plaintext (raw DB query to verify)
- Agent cannot read another agent's scoped secret
- Agent cannot read a secret from another company
- Vault decrypts correctly with correct key
- Vault returns error with wrong key
- Rotation changes value and updates last_rotated_at
```

---

## PHASE 7: OBSERVABILITY

### Prompt 7.1 — Telemetry & OpenTelemetry

```
Implement full observability for PaperclipEx.

Files:
- paperclipex_core/lib/paperclipex_core/telemetry.ex
- paperclipex_web/lib/paperclipex_web/telemetry.ex

Telemetry events to emit (use :telemetry.execute/3):
- [:paperclipex, :heartbeat, :start] — %{agent_id, run_id, trigger}
- [:paperclipex, :heartbeat, :stop] — %{agent_id, run_id, duration_ms, cost_cents}
- [:paperclipex, :heartbeat, :exception] — %{agent_id, run_id, error}
- [:paperclipex, :issue, :checkout] — %{issue_id, agent_id, success}
- [:paperclipex, :budget, :exhausted] — %{agent_id, company_id}
- [:paperclipex, :approval, :created] — %{type, agent_id}
- [:paperclipex, :approval, :decided] — %{type, decision}

TelemetryMetricsPrometheus (expose /metrics endpoint):
- paperclipex_heartbeat_duration_ms (histogram)
- paperclipex_heartbeat_cost_cents (counter)
- paperclipex_active_agents (gauge)
- paperclipex_budget_utilization (gauge)
- paperclipex_issues_completed (counter)

OpenTelemetry:
- opentelemetry_phoenix: auto-instrument Phoenix requests
- opentelemetry_ecto: auto-instrument Ecto queries
- opentelemetry_oban: auto-instrument Oban jobs
- Export to OTLP endpoint (configurable via OTEL_EXPORTER_OTLP_ENDPOINT env var)

LiveDashboard:
- Mount at /dev/dashboard (dev) and /ops/dashboard (prod, board operator only)
- Add Oban.Web panel
- Custom metrics page with heartbeat stats

Health check endpoint:
GET /health → 200 with JSON:
{
  "status": "ok",
  "database": "connected",
  "oban_queue_depth": 42,
  "beam_node": "paperclipex@hostname",
  "version": "0.1.0"
}
```

---

## PHASE 8: PRODUCTION DEPLOYMENT

### Prompt 8.1 — Docker & Fly.io

```
Create production deployment configuration.

Files to create:
- Dockerfile (multi-stage)
- .dockerignore
- fly.toml
- config/runtime.exs (all env var config)
- rel/env.sh.eex (release env setup)

Dockerfile requirements:
Stage 1 (builder):
  FROM elixir:1.17-otp-27-alpine AS builder
  - Install build deps: build-base, git, nodejs, npm
  - Copy mix files, fetch deps
  - Copy source, compile release
  - mix assets.deploy for Tailwind
  - mix release paperclipex

Stage 2 (runner):
  FROM alpine:3.20 AS runner
  - Install runtime: libstdc++, openssl, ncurses-libs
  - Copy release from builder
  - Run as non-root user
  - EXPOSE 4000
  - CMD: /app/bin/paperclipex start

config/runtime.exs must read from environment:
  - DATABASE_URL — PostgreSQL connection string
  - SECRET_KEY_BASE — Phoenix secret (64+ chars)
  - CLOAK_KEY — base64 AES-256 key
  - PHX_HOST — public hostname
  - PORT — default 4000
  - OTEL_EXPORTER_OTLP_ENDPOINT — optional
  - SENTRY_DSN — optional
  - PAPERCLIPEX_AUTH_MODE — local_trusted | authenticated_private | authenticated_public
  - MAX_HEARTBEAT_CONCURRENCY — Oban queue concurrency (default 20)

fly.toml:
  - app name: paperclipex
  - region: lhr (London, near Leeds)
  - 1 web machine (512MB, 1 shared CPU)
  - 1 Postgres cluster (development plan)
  - Auto-scale to 0 overnight
  - Health check on /health

Release tasks:
  - mix release includes Ecto.Migrator.run on startup (auto-migrate)
  - Provide paperclipex eval "PaperclipEx.Release.migrate()" for manual run

Write a Makefile with targets:
  - make build → docker build
  - make deploy → fly deploy
  - make migrate → fly ssh console -C "/app/bin/paperclipex eval PaperclipEx.Release.migrate()"
  - make seed → run seed data in production
  - make console → fly ssh console with IEx
```

---

## REFERENCE: PUBSUB CONTRACTS

```
All PubSub messages follow this contract. Adapters and workers MUST use these
exact message shapes to ensure LiveView handlers work correctly.

Topic: "companies:{company_id}:agents"
Messages:
  {:agent_status_changed, %{agent_id: uuid, old_status: atom, new_status: atom}}
  {:agent_hired, %{agent: Agent.t()}}
  {:agent_terminated, %{agent_id: uuid}}
  {:agent_budget_alert, %{agent_id: uuid, percentage: float}}

Topic: "companies:{company_id}:runs"
Messages:
  {:run_started, %{run_id: uuid, agent_id: uuid, trigger: atom}}
  {:run_completed, %{run: HeartbeatRun.t()}}
  {:run_failed, %{run_id: uuid, error: String.t()}}

Topic: "runs:{run_id}:stdout"
Messages:
  {:stdout_chunk, chunk :: String.t()}
  {:run_completed, %{run: HeartbeatRun.t()}}

Topic: "companies:{company_id}:approvals"
Messages:
  {:approval_requested, %{approval: Approval.t()}}
  {:approval_decided, %{approval_id: uuid, decision: :approved | :rejected}}

Topic: "companies:{company_id}:costs"
Messages:
  {:spend_updated, %{agent_id: uuid, cost_cents: integer, total_cents: integer}}
  {:budget_exhausted, %{agent_id: uuid, company_id: uuid}}
```
