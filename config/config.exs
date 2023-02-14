import Config

config :papahome,
  env:                  config_env(),
  ecto_repos:           [Papahome.Repo],
  signup_member_credit: 100,    # Number of minutes granted to member at signup
  fee_overhead:         0.15    # Fee overhead percentage of minutes (0.15 = 15%)

config :logger,
  level: :info

import_config("#{config_env()}.exs")
