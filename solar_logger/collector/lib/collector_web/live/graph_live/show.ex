defmodule CollectorWeb.GraphLive.Show do
  use CollectorWeb, :live_view

  import Ecto.Query

  alias Collector.Visual

  @which :solar

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Collector.PubSub, "uploads")
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _, socket) do
    graph = Visual.Graph.new(params)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:graph, graph)
     |> assign_plot(@which)}
  end

  defp assign_plot(socket, :solar) do
    latlng = %Collector.Solar.LatLng{latitude: 37.94, longitude: -122.55}
    graph = socket.assigns.graph

    plot =
      Collector.Solar.create_plot(
        [:solar_energy],
        latlng,
        graph.from,
        graph.to
      )

    socket
    |> assign(:plot, plot)
    |> assign_new(:updated, fn -> "never" end)
  end

  defp assign_plot(socket, :data) do
    graph = socket.assigns.graph

    query =
      base_query =
      case graph.domain do
        "Cpu" -> Collector.System.Cpu
        "Vmemory" -> Collector.System.Vmemory
        "Luminosity" -> Collector.Solar.Luminosity
        _ -> nil
      end

    if is_nil(query) do
      plot = Visual.Graph.plot([], graph.items)
      assign(socket, plot: plot, updated: "never")
    else
      query =
        if graph.from do
          query |> where([i], i.at >= ^graph.from)
        else
          query
        end

      query =
        if graph.to do
          query |> where([i], i.at <= ^graph.to)
        else
          query
        end

      data =
        query
        |> Collector.Repo.all()
        |> Enum.map(&Map.from_struct/1)

      last_data =
        base_query
        |> last(:at)
        |> Collector.Repo.one()

      updated =
        if is_nil(last_data) do
          "never"
        else
          last_data.at
        end

      plot = Visual.Graph.plot(data, graph.items)
      assign(socket, plot: plot, updated: updated)
    end
  end

  @impl true
  def handle_info({CollectorWeb.GraphLive.FormComponent, {:saved, graph}}, socket) do
    {:noreply,
     socket
     |> assign(:graph, graph)
     |> assign_plot(@which)}
  end

  def handle_info({:data_uploaded, %{domain: domain}}, socket) do
    socket =
      if @which == :data && socket.assigns.graph.domain == domain do
        assign_plot(socket, :data)
      else
        socket
      end

    {:noreply, socket}
  end

  defp page_title(:show), do: "Show Graph"
  defp page_title(:edit), do: "Edit Graph"
end
