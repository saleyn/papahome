import Config

config :papahome, Papahome.Repo,
  database: "papa_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
