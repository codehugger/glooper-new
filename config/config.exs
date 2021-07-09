# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :glooper,
  ecto_repos: [Glooper.Repo]

# Configures the endpoint
config :glooper, GlooperWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "m2Q81HvMNTTUUD8QH0x05cm2i7BbhkNFHs3by1GYl0Pl9MawNr8zv+gYGaTayfjw",
  render_errors: [view: GlooperWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Glooper.PubSub,
  live_view: [signing_salt: "F8qqG975"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# Glooper Engine configuration
config :glooper,
  # The Glooper nanoid alphabet uses hex for easy readability
  alphabet: "0123456789ABCDEF",

  # Simulations and agents
  agent_no_digits: 6,
  sim_no_digits: 10
