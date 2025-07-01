import Config

config :reddevs,
  token_signing_secret:
    System.get_env("TEST_TOKEN_SIGNING_SECRET") || "zoJl/UklLWo3UxM2cQfDsgcUdLhuyXKY"

config :bcrypt_elixir, log_rounds: 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :reddevs, Reddevs.Repo,
  username: System.get_env("TEST_DB_USERNAME") || "postgres",
  password: System.get_env("TEST_DB_PASSWORD") || "postgres",
  hostname: System.get_env("TEST_DB_HOST") || "localhost",
  database:
    System.get_env("TEST_DB_NAME") || "reddevs_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :reddevs, ReddevsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("TEST_PORT") || "4002")],
  secret_key_base: System.get_env("TEST_SECRET_KEY_BASE"),
  server: false

# In test we don't send emails
config :reddevs, Reddevs.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :reddevs, Reddevs.Secrets, signing_secret: System.get_env("TEST_SIGNING_SECRET")

config :reddevs, :github,
  client_id: System.get_env("TEST_GITHUB_CLIENT_ID"),
  client_secret: System.get_env("TEST_GITHUB_CLIENT_SECRET"),
  redirect_uri:
    System.get_env("TEST_GITHUB_REDIRECT_URI") ||
      "http://localhost:4000/auth/user/github/callback"

config :reddevs, :google,
  client_id: System.get_env("TEST_GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("TEST_GOOGLE_CLIENT_SECRET"),
  redirect_uri:
    System.get_env("TEST_GOOGLE_REDIRECT_URI") ||
      "http://localhost:4000/auth/user/google/callback"
