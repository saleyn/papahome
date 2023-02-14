import Config

if Application.get_env(:papahome, :env) != :test do
  config :papahome, Papahome.Repo,
    database: System.get_env("DB_NAME", "papa_dev"),
    username: System.get_env("DB_USER", "postgres"),
    password: System.get_env("DB_PASS", "postgres"),
    hostname: System.get_env("DB_HOST", "localhost")
end
