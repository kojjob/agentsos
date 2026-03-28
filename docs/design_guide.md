# PaperclipEx — Design Guide
## Visual Identity, UI System & Component Patterns

---

## 1. DESIGN PHILOSOPHY

PaperclipEx is an **operations control plane**. The people using it are founders and engineers
managing AI agent teams. They need clarity, density, and trust — not decoration.

**Core aesthetic:** Industrial Precision. Like a Bloomberg Terminal crossed with Linear.
Dark-dominant. High information density. Every pixel earns its place.

**Design axioms:**
1. **Clarity over beauty** — information hierarchy always wins
2. **Density is not noise** — pack more into less space, never sacrifice scan-ability
3. **Status is sacred** — agent status, job status, budget status must be instantly readable
4. **Real-time is assumed** — the UI should feel alive, not static
5. **Trust through transparency** — everything that happened should be findable

---

## 2. COLOR SYSTEM

### Philosophy
Dark base with sharp, saturated status colors. The background recedes; the data speaks.
Never use color decoratively — every color communicates meaning.

### CSS Variables
```css
:root {
  /* Base */
  --color-bg-primary:     #0a0b0d;   /* Near-black canvas */
  --color-bg-secondary:   #111318;   /* Card/panel backgrounds */
  --color-bg-tertiary:    #1a1d24;   /* Input, nested surfaces */
  --color-bg-elevated:    #21252e;   /* Hover states, tooltips */

  /* Borders */
  --color-border-subtle:  #1f2330;   /* Most dividers */
  --color-border-default: #2a2f3d;   /* Card edges */
  --color-border-strong:  #3d4357;   /* Focus rings, emphasis */

  /* Text */
  --color-text-primary:   #e8eaf0;   /* Main content */
  --color-text-secondary: #8b91a8;   /* Labels, metadata */
  --color-text-tertiary:  #545970;   /* Placeholder, disabled */
  --color-text-inverse:   #0a0b0d;   /* On accent backgrounds */

  /* Brand Accent */
  --color-accent:         #4f6ef7;   /* Primary CTA, links */
  --color-accent-hover:   #6b85ff;   /* Hover on accent */
  --color-accent-subtle:  #1a2247;   /* Accent surface (tag bg, etc.) */
  --color-accent-text:    #96a8ff;   /* Accent text on dark bg */

  /* Status — Agents */
  --color-status-active:  #22c55e;   /* Active / idle */
  --color-status-running: #3b82f6;   /* Running / in_progress */
  --color-status-error:   #ef4444;   /* Error / blocked */
  --color-status-paused:  #f59e0b;   /* Paused / pending */
  --color-status-terminated: #6b7280; /* Terminated / cancelled */
  --color-status-pending: #a855f7;   /* pending_approval */

  /* Status — Issues */
  --color-issue-backlog:  #545970;
  --color-issue-todo:     #8b91a8;
  --color-issue-progress: #3b82f6;
  --color-issue-review:   #a855f7;
  --color-issue-done:     #22c55e;
  --color-issue-blocked:  #ef4444;
  --color-issue-cancelled:#545970;

  /* Semantic */
  --color-success:        #22c55e;
  --color-warning:        #f59e0b;
  --color-danger:         #ef4444;
  --color-info:           #3b82f6;

  /* Budget */
  --color-budget-safe:    #22c55e;   /* <70% used */
  --color-budget-caution: #f59e0b;   /* 70–90% used */
  --color-budget-critical:#ef4444;   /* >90% used */
}
```

### Status Color Usage Rules
- **Never** use status colors for decoration
- Status dots must always be 8px, circular, with a 2px matching outer ring (using opacity 0.3)
- Running agents use a pulsing animation on the status dot
- Error state adds a subtle red tint to the card background

---

## 3. TYPOGRAPHY

### Font Stack
```css
/* Display / Headers */
@import url('https://fonts.googleapis.com/css2?family=Geist+Mono:wght@400;500;600&display=swap');

/* Body */
@import url('https://fonts.googleapis.com/css2?family=Geist:wght@300;400;500;600&display=swap');

:root {
  --font-display: 'Geist Mono', 'JetBrains Mono', monospace;
  --font-body:    'Geist', 'SF Pro Text', -apple-system, sans-serif;
  --font-mono:    'Geist Mono', 'Fira Code', monospace;
}
```

**Rationale:** Geist Mono for headings and labels gives an engineering terminal aesthetic.
Geist (sans) for body keeps it readable at density. No system fonts — too generic.

### Type Scale
```css
:root {
  --text-xs:   11px;   /* Timestamps, secondary metadata */
  --text-sm:   12px;   /* Labels, badges, sidebar items */
  --text-base: 14px;   /* Default body text */
  --text-md:   15px;   /* Emphasized body */
  --text-lg:   18px;   /* Section headings */
  --text-xl:   22px;   /* Page titles */
  --text-2xl:  28px;   /* Dashboard metrics */
  --text-3xl:  36px;   /* Hero numbers (cost, agent count) */

  --font-weight-normal:   400;
  --font-weight-medium:   500;
  --font-weight-semibold: 600;

  --leading-tight:  1.2;
  --leading-normal: 1.5;
  --leading-loose:  1.75;
}
```

### Typography Rules
- All metric/number displays: `--font-display` (monospace) — never body font for numbers
- All code, logs, JWT, secrets: `--font-mono`
- Section headings: 12px, `--font-display`, uppercase, letter-spacing 0.08em
- Never use font-size below 11px
- Line lengths: max 72 characters for prose; unconstrained for data tables

---

## 4. SPACING & LAYOUT

### Spacing Scale
```css
:root {
  --space-1:  4px;
  --space-2:  8px;
  --space-3:  12px;
  --space-4:  16px;
  --space-5:  20px;
  --space-6:  24px;
  --space-8:  32px;
  --space-10: 40px;
  --space-12: 48px;
  --space-16: 64px;
}
```

### Layout Structure
```
┌─────────────────────────────────────────────────────────────┐
│  Topbar (56px)                                              │
│  [Logo] [Company selector] .......... [Budget] [Profile]   │
├───────────┬─────────────────────────────────────────────────┤
│           │                                                 │
│  Sidebar  │  Main Content Area                              │
│  (220px)  │  (flex 1)                                       │
│           │                                                 │
│  Nav:     │  Page title + actions (48px)                    │
│  Dashboard│  ─────────────────────────────────────          │
│  Agents   │                                                 │
│  Issues   │  Content (scrollable)                           │
│  Goals    │                                                 │
│  Costs    │                                                 │
│  Activity │                                                 │
│  Settings │                                                 │
│           │                                                 │
└───────────┴─────────────────────────────────────────────────┘
```

### Grid System
- Main content: 12-column grid with 16px gutters
- Cards: typically span 4 or 6 columns
- Full-width tables: 12 columns
- Dashboard metrics: 3 or 4 across on desktop
- Mobile: single column, sidebar collapses to bottom nav

### Border Radius
```css
:root {
  --radius-sm:  4px;   /* Badges, chips, small elements */
  --radius-md:  6px;   /* Cards, inputs, buttons */
  --radius-lg:  8px;   /* Modals, panels */
  --radius-xl:  12px;  /* Featured cards */
  --radius-full: 9999px; /* Status dots, pills */
}
```

---

## 5. COMPONENT PATTERNS

### Agent Status Card
```heex
<div class="agent-card" data-status={agent.status}>
  <div class="agent-card__header">
    <div class="status-indicator status-indicator--{agent.status}" />
    <span class="agent-card__name">{agent.name}</span>
    <span class="agent-card__role">{agent.role_title}</span>
  </div>
  <div class="agent-card__task">
    <%= if agent.current_task do %>
      <span class="task-chip">{agent.current_task.title}</span>
    <% else %>
      <span class="idle-label">Idle</span>
    <% end %>
  </div>
  <div class="agent-card__budget">
    <BudgetGauge percent={agent.spend_percentage} />
  </div>
</div>
```

**CSS:**
```css
.agent-card {
  background: var(--color-bg-secondary);
  border: 1px solid var(--color-border-default);
  border-radius: var(--radius-md);
  padding: var(--space-4);
  transition: border-color 150ms ease;
}

.agent-card:hover {
  border-color: var(--color-border-strong);
}

.agent-card[data-status="running"] {
  border-left: 3px solid var(--color-status-running);
}

.agent-card[data-status="error"] {
  border-left: 3px solid var(--color-status-error);
  background: color-mix(in srgb, var(--color-bg-secondary) 95%, var(--color-status-error) 5%);
}
```

### Status Indicator (Dot)
```css
.status-indicator {
  width: 8px;
  height: 8px;
  border-radius: var(--radius-full);
  flex-shrink: 0;
  position: relative;
}

.status-indicator::after {
  content: '';
  position: absolute;
  inset: -3px;
  border-radius: var(--radius-full);
  opacity: 0.3;
}

.status-indicator--active,
.status-indicator--idle {
  background: var(--color-status-active);
  &::after { background: var(--color-status-active); }
}

.status-indicator--running {
  background: var(--color-status-running);
  &::after { background: var(--color-status-running); }
  animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
}

.status-indicator--error {
  background: var(--color-status-error);
  &::after { background: var(--color-status-error); }
}

.status-indicator--paused {
  background: var(--color-status-paused);
}

.status-indicator--pending {
  background: var(--color-status-pending);
}

.status-indicator--terminated {
  background: var(--color-status-terminated);
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50%       { opacity: 0.4; }
}
```

### Budget Gauge
```heex
<div class="budget-gauge">
  <div class="budget-gauge__bar">
    <div
      class="budget-gauge__fill"
      style={"width: #{min(percent, 100)}%"}
      data-level={budget_level(percent)}
    />
  </div>
  <span class="budget-gauge__label">
    {format_cents(used)} / {format_cents(limit)}
  </span>
</div>
```

```css
.budget-gauge__bar {
  height: 4px;
  background: var(--color-bg-tertiary);
  border-radius: var(--radius-full);
  overflow: hidden;
}

.budget-gauge__fill {
  height: 100%;
  border-radius: var(--radius-full);
  transition: width 500ms ease;
}

.budget-gauge__fill[data-level="safe"]     { background: var(--color-budget-safe); }
.budget-gauge__fill[data-level="caution"]  { background: var(--color-budget-caution); }
.budget-gauge__fill[data-level="critical"] {
  background: var(--color-budget-critical);
  animation: pulse 1.5s ease infinite;
}
```

### Issue Kanban Column
```css
.kanban-column {
  min-width: 260px;
  max-width: 300px;
  background: var(--color-bg-secondary);
  border: 1px solid var(--color-border-subtle);
  border-radius: var(--radius-lg);
  padding: var(--space-4);
}

.kanban-column__header {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  margin-bottom: var(--space-4);
  padding-bottom: var(--space-3);
  border-bottom: 1px solid var(--color-border-subtle);
  font-family: var(--font-display);
  font-size: var(--text-xs);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--color-text-secondary);
}

.issue-card {
  background: var(--color-bg-primary);
  border: 1px solid var(--color-border-subtle);
  border-radius: var(--radius-md);
  padding: var(--space-3);
  margin-bottom: var(--space-2);
  cursor: pointer;
  transition: border-color 100ms ease, transform 100ms ease;
}

.issue-card:hover {
  border-color: var(--color-border-default);
  transform: translateY(-1px);
}

.issue-card--checked-out {
  border-left: 3px solid var(--color-status-running);
}
```

### Terminal / Run Viewer
```css
.terminal {
  background: #060709;
  border: 1px solid var(--color-border-subtle);
  border-radius: var(--radius-lg);
  font-family: var(--font-mono);
  font-size: var(--text-sm);
  line-height: var(--leading-loose);
  color: #d4d4d4;
  padding: var(--space-4);
  overflow-y: auto;
  max-height: 600px;
}

.terminal__line { display: block; }
.terminal__line--tool-use { color: #569cd6; }
.terminal__line--result   { color: #4ec9b0; }
.terminal__line--error    { color: #f44747; }
.terminal__line--system   { color: var(--color-text-tertiary); }

.terminal__cursor {
  display: inline-block;
  width: 8px;
  height: 14px;
  background: #e8eaf0;
  animation: blink 1s step-end infinite;
  vertical-align: text-bottom;
}

@keyframes blink {
  0%, 100% { opacity: 1; }
  50%       { opacity: 0; }
}
```

### Data Table
```css
.data-table {
  width: 100%;
  border-collapse: collapse;
  font-size: var(--text-sm);
}

.data-table th {
  font-family: var(--font-display);
  font-size: var(--text-xs);
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--color-text-tertiary);
  font-weight: var(--font-weight-medium);
  padding: var(--space-2) var(--space-4);
  text-align: left;
  border-bottom: 1px solid var(--color-border-subtle);
}

.data-table td {
  padding: var(--space-3) var(--space-4);
  color: var(--color-text-primary);
  border-bottom: 1px solid var(--color-border-subtle);
}

.data-table tr:hover td {
  background: var(--color-bg-elevated);
}

.data-table tr:last-child td {
  border-bottom: none;
}
```

### Button System
```css
/* Primary */
.btn-primary {
  background: var(--color-accent);
  color: white;
  border: none;
  border-radius: var(--radius-md);
  padding: var(--space-2) var(--space-4);
  font-size: var(--text-sm);
  font-weight: var(--font-weight-medium);
  cursor: pointer;
  transition: background 100ms ease;
}
.btn-primary:hover { background: var(--color-accent-hover); }

/* Secondary */
.btn-secondary {
  background: transparent;
  color: var(--color-text-primary);
  border: 1px solid var(--color-border-default);
  border-radius: var(--radius-md);
  padding: var(--space-2) var(--space-4);
  font-size: var(--text-sm);
  cursor: pointer;
  transition: border-color 100ms ease, background 100ms ease;
}
.btn-secondary:hover {
  border-color: var(--color-border-strong);
  background: var(--color-bg-elevated);
}

/* Danger */
.btn-danger {
  background: transparent;
  color: var(--color-danger);
  border: 1px solid color-mix(in srgb, var(--color-danger) 40%, transparent);
  border-radius: var(--radius-md);
  padding: var(--space-2) var(--space-4);
  font-size: var(--text-sm);
  cursor: pointer;
  transition: all 100ms ease;
}
.btn-danger:hover {
  background: color-mix(in srgb, var(--color-danger) 10%, transparent);
  border-color: var(--color-danger);
}

/* Icon Button */
.btn-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border-radius: var(--radius-md);
  background: transparent;
  border: none;
  color: var(--color-text-secondary);
  cursor: pointer;
  transition: background 100ms ease, color 100ms ease;
}
.btn-icon:hover {
  background: var(--color-bg-elevated);
  color: var(--color-text-primary);
}
```

---

## 6. LIVEVIEW-SPECIFIC PATTERNS

### Live Update Flicker Prevention
```css
/* Prevent layout shift during PubSub updates */
.agent-grid { contain: layout; }
.issue-card { will-change: auto; }

/* Highlight newly updated elements */
@keyframes highlight-update {
  0%   { background: color-mix(in srgb, var(--color-accent) 15%, transparent); }
  100% { background: transparent; }
}

.just-updated {
  animation: highlight-update 800ms ease-out forwards;
}
```

Apply in LiveView:
```elixir
def handle_info({:agent_status_changed, %{agent_id: id}}, socket) do
  {:noreply, push_event(socket, "highlight", %{id: "agent-#{id}"})}
end
```

### Streaming Output (Run Viewer)
```javascript
// In app.js hooks
Hooks.RunViewer = {
  mounted() {
    this.handleEvent("scroll_to_bottom", () => {
      this.el.scrollTop = this.el.scrollHeight;
    });
    this.handleEvent("highlight", ({id}) => {
      const el = document.getElementById(id);
      if (el) {
        el.classList.remove("just-updated");
        void el.offsetWidth; // force reflow
        el.classList.add("just-updated");
      }
    });
  }
}
```

---

## 7. PAGE-SPECIFIC DESIGN

### Dashboard — Layout Intent
- 3-column grid at top: key metrics (agents running, open issues, pending approvals, spend)
- Full-width: Agent Status Grid (2-column, card per agent, max 10 visible, scroll)
- Split: [Activity Feed 60%] [Burn Rate + Approvals 40%]
- Approvals queue: approve/reject inline (no modal) — speed matters

### Org Chart — Layout Intent
- Horizontal tree flowing left-to-right (not top-down — agents nest deeply)
- CEO node: larger, full company goal shown
- Each node: name, role, status dot, truncated current task
- Click node → slide-in panel with agent detail (no navigation)
- Collapse/expand subtrees
- No external graph library — pure CSS flex tree or D3-lite via hook

### Run Viewer — Layout Intent
- Full-screen takeover optional (keyboard shortcut F)
- Left: terminal (dark, monospace, streaming)
- Right panel (320px): run metadata
  - Agent name + trigger type
  - Live elapsed timer (HH:MM:SS, monospace)
  - Token counter (input: X, output: Y)
  - Estimated cost (live)
  - Issues touched (list)
- Bottom: final summary card (only after completion)

### Issues Kanban — Layout Intent
- Horizontal scroll for columns
- Column headers: status name + count badge
- Issue card density: title + assignee avatar + priority chip
- Checked-out issues: blue left border + "locked" icon
- Click card → slide-in detail panel (not navigation) — context preserved

---

## 8. ANIMATION SYSTEM

```css
:root {
  --duration-instant: 80ms;
  --duration-fast:    150ms;
  --duration-normal:  250ms;
  --duration-slow:    400ms;

  --ease-default:  cubic-bezier(0.4, 0, 0.2, 1);
  --ease-in:       cubic-bezier(0.4, 0, 1, 1);
  --ease-out:      cubic-bezier(0, 0, 0.2, 1);
  --ease-spring:   cubic-bezier(0.34, 1.56, 0.64, 1);
}
```

### Animation Rules
- Status changes: instant (80ms) — faster than human perception, feels snappy
- Card hover: fast (150ms)
- Modal open/close: normal (250ms)
- Slide-in panels: slow (400ms) with ease-spring
- Page transitions: none (LiveView renders instantly, animate content not layout)
- Pulsing status dots (running agent): 2s ease infinite
- Budget critical blink: 1.5s ease infinite

### What NOT to animate
- Table row updates (too jarring at scale)
- Budget number changes (they change too frequently)
- Sidebar navigation (instant)
- Data loading states (use skeleton screens, not spinners)

---

## 9. TAILWIND CONFIGURATION

```javascript
// tailwind.config.js
module.exports = {
  content: ["./lib/**/*.{heex,ex,js}"],
  theme: {
    extend: {
      fontFamily: {
        display: ["'Geist Mono'", "monospace"],
        body:    ["'Geist'", "sans-serif"],
        mono:    ["'Geist Mono'", "monospace"],
      },
      colors: {
        bg: {
          primary:   "#0a0b0d",
          secondary: "#111318",
          tertiary:  "#1a1d24",
          elevated:  "#21252e",
        },
        border: {
          subtle:  "#1f2330",
          default: "#2a2f3d",
          strong:  "#3d4357",
        },
        text: {
          primary:   "#e8eaf0",
          secondary: "#8b91a8",
          tertiary:  "#545970",
        },
        accent: "#4f6ef7",
        status: {
          active:     "#22c55e",
          running:    "#3b82f6",
          error:      "#ef4444",
          paused:     "#f59e0b",
          terminated: "#6b7280",
          pending:    "#a855f7",
        },
      },
      animation: {
        "pulse-dot": "pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite",
        "pulse-critical": "pulse 1.5s ease infinite",
        "highlight": "highlight-update 800ms ease-out forwards",
      },
    },
  },
  plugins: [require("@tailwindcss/forms"), require("@tailwindcss/typography")],
}
```

---

## 10. ICONOGRAPHY

**Library:** Heroicons (solid for actions, outline for navigation, mini for dense UI)

**Usage rules:**
- Navigation icons: 20px outline
- Action buttons: 16px solid
- Status indicators: never use icons, always use color dots
- Empty states: 48px outline, --color-text-tertiary
- Error states: 24px solid, --color-danger

**Avoid:** Random icon libraries, emoji as UI icons, icon fonts (use SVG only)

---

## 11. DARK MODE ONLY

PaperclipEx is **dark mode only**. Operators work in terminals. The dashboard should feel
like an extension of their environment, not a consumer app.

No `prefers-color-scheme` toggle. No light theme. The product identity is built around
this decision.

---

## 12. ACCESSIBILITY

- Color is never the only indicator of state (always pair with label or icon)
- Status dots have `aria-label` with status name
- All interactive elements: 2px focus ring, --color-accent, offset 2px
- Minimum contrast 4.5:1 for all text
- Keyboard navigation: Tab, Shift+Tab through all interactive elements
- Escape closes all modals and slide-in panels
- LiveView updates: `phx-update="append"` sections have `aria-live="polite"`

```css
:focus-visible {
  outline: 2px solid var(--color-accent);
  outline-offset: 2px;
}
```

---

## 13. RESPONSIVE BREAKPOINTS

```css
/* Mobile-first (operators on the go) */
--bp-sm:  640px;   /* Small tablet */
--bp-md:  768px;   /* Tablet */
--bp-lg:  1024px;  /* Small laptop (minimum for full dashboard) */
--bp-xl:  1280px;  /* Standard desktop */
--bp-2xl: 1536px;  /* Large desktop */
```

**Responsive behaviour:**
- < 1024px: sidebar collapses to icon-only (hover to expand)
- < 768px: sidebar moves to bottom tab bar
- < 640px: kanban columns stack vertically
- Run viewer: terminal takes full width on all screen sizes
- Metrics bar: wraps to 2x2 grid on tablet, 1x4 on desktop
