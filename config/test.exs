use Mix.Config

# Print only warnings and errors during test
config :logger, :console, level: :warn, format: "[$level] $message\n"

config :ex_unit, capture_log: true

config :commanded, event_store_adapter: Commanded.EventStore.Adapters.InMemory

config :commanded_postgres_read_model_projector,
  ecto_repos: [Commanded.Projections.Repo],
  repo: Commanded.Projections.Repo

config :commanded_postgres_read_model_projector, Commanded.Projections.Repo,
  database: "commanded_postgres_read_model_projector_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
