defmodule Commanded.Projections.Repo do
  use Ecto.Repo,
    otp_app: :commanded_postgres_read_model_projector,
    adapter: Ecto.Adapters.Postgres
end
