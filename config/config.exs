# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :agent_sos,
  env: config_env(),
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :agent_sos, AgentSosWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AgentSosWeb.ErrorHTML, json: AgentSosWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: AgentSos.PubSub,
  live_view: [signing_salt: "MnhgwL4O"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :agent_sos, AgentSos.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  agent_sos: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  agent_sos: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Ash Framework
config :agent_sos,
  ash_domains: [
    AgentSos.Accounts,
    AgentSos.Agents,
    AgentSos.Billing,
    AgentSos.Notifications,
    AgentSos.Audit,
    AgentSos.FeatureFlags,
    AgentSos.Webhooks,
    AgentSos.Analytics,
    AgentSos.Issues,
    AgentSos.Runs,
    AgentSos.Goals,
    AgentSos.Approvals,
    AgentSos.Secrets,
    AgentSos.Templates
  ]

# Token signing secret — loaded from env var; fallback only for dev/test
config :agent_sos,
  token_signing_secret: System.get_env("TOKEN_SIGNING_SECRET", "dev-only-not-for-production-at-least-32-bytes!!")

# Database
config :agent_sos, AgentSos.Repo,
  migration_primary_key: [name: :id, type: :binary_id]

config :agent_sos,
  ecto_repos: [AgentSos.Repo]

# Oban
config :agent_sos, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10, mailers: 20, billing: 5, heartbeats: 20],
  repo: AgentSos.Repo

# Stripe (keys loaded from runtime.exs)
config :stripity_stripe,
  api_version: "2024-04-10"

# Import branding and plans config
import_config "branding.exs"
import_config "plans.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
