# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :collector,
  location: "Kentfield",
  latitude: 37.94,
  longitude: -122.55,
  time_zone: "America/Los_Angeles"

config :collector,
  ecto_repos: [Collector.Repo],
  generators: [timestamp_type: :utc_datetime_usec]

# Configures the endpoint
config :collector, CollectorWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: CollectorWeb.ErrorHTML, json: CollectorWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Collector.PubSub,
  live_view: [signing_salt: "lz+whTge"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  collector: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  collector: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
