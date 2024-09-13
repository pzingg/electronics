defmodule Collector.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CollectorWeb.Telemetry,
      Collector.Repo,
      {DNSCluster, query: Application.get_env(:collector, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Collector.PubSub},
      # Start a worker by calling: Collector.Worker.start_link(arg)
      # {Collector.Worker, arg},
      # Start to serve requests, typically the last entry
      CollectorWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Collector.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CollectorWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def latlng do
    latitude = Application.fetch_env!(:collector, :latitude)
    longitude = Application.fetch_env!(:collector, :longitude)
    Collector.Solar.LatLng.new(latitude, longitude)
  end

  def time_zone do
    Application.fetch_env!(:collector, :time_zone)
  end
end
