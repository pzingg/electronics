defmodule CollectorWeb.PageController do
  use CollectorWeb, :controller

  require Logger

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def import(conn, %{"table" => table, "rows" => rows}) do
    # Json data imported here

    result =
      case table do
        "cpu" ->
          Collector.Repo.ingest(Collector.System.Cpu, rows)

        "vmemory" ->
          Collector.Repo.ingest(Collector.System.Vmemory, rows)

        "luminosity" ->
          Collector.Repo.ingest(Collector.Solar.Luminosity, rows)

        _ ->
          {:error, "can't ingest '#{table}'"}
      end

    case result do
      {:ok, ats} ->
        at = Enum.max(ats)

        Phoenix.PubSub.broadcast(
          Collector.PubSub,
          "uploads",
          {:data_uploaded, %{domain: String.capitalize(table), updated: at}}
        )

        data = %{table: table, rows: rows}
        response = %{record: data, metadata: %{private: true}}
        json(conn, response)

      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{message: "Bad request", details: reason})
    end
  end

  def samples(conn, _params) do
    latlng = Collector.Application.latlng()
    time_zone = Collector.Application.time_zone()

    full_year_plot =
      Collector.Solar.insolation_plot(
        [:solar_energy_incident],
        latlng,
        ~N[2024-01-01 00:00:00],
        ~N[2024-12-31 23:50:00],
        time_zone: time_zone,
        interval: {30, :minute}
      )

    october_plot =
      Collector.Solar.insolation_plot(
        [:solar_energy_incident],
        latlng,
        ~N[2024-10-01 00:00:00],
        ~N[2024-10-31 23:50:00],
        time_zone: time_zone,
        interval: {30, :minute}
      )

    halloween_plot =
      Collector.Solar.insolation_plot(
        [:solar_energy_incident, :solar_energy_module],
        latlng,
        ~N[2024-10-31 04:00:00],
        ~N[2024-10-31 20:00:00],
        time_zone: time_zone,
        interval: {10, :minute}
      )

    plots = [
      {"Full year", full_year_plot},
      {"October", october_plot},
      {"Halloween", halloween_plot}
    ]

    render(conn, :samples, plots: plots)
  end
end
