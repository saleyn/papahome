defmodule Papahome.Repo do
  use Ecto.Repo,
    otp_app: :papahome,
    adapter: Ecto.Adapters.Postgres
end
