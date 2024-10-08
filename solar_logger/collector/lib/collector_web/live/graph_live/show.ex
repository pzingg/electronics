defmodule CollectorWeb.GraphLive.Show do
  use CollectorWeb, :live_view

  import Ecto.Query

  alias Collector.Solar.{LatLng, Luminosity, Panel}
  alias Collector.Visual

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Collector.PubSub, "uploads")
    end

    from = NaiveDateTime.local_now()
    from = %NaiveDateTime{from | hour: 0, minute: 0, second: 0}
    to = NaiveDateTime.add(from, 24, :hour)

    attrs = %{
      from: from,
      to: to
    }

    graph = Visual.Graph.new(attrs)

    socket =
      socket
      |> assign(:domains, Visual.Graph.domains())
      |> assign_graph(graph)
      |> assign_plot()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _, socket) do
    action = socket.assigns.live_action

    result =
      socket.assigns.graph
      |> Visual.Graph.changeset(params)
      |> Ecto.Changeset.apply_action(action)

    socket =
      case result do
        {:ok, graph} -> assign_graph(socket, graph)
        _ -> socket
      end

    {:noreply,
     socket
     |> assign(:page_title, page_title(action))
     |> assign_plot()}
  end

  defp assign_graph(socket, graph) do
    graph_from = Visual.Graph.strftime(graph.from)
    graph_to = Visual.Graph.strftime(graph.to)
    graph_items = Enum.join(graph.items, ", ")

    assign(socket,
      graph: graph,
      graph_from: graph_from,
      graph_to: graph_to,
      graph_items: graph_items
    )
  end

  defp assign_plot(socket) do
    lat_lng = Collector.Application.lat_lng()
    time_zone = Collector.Application.time_zone()
    graph = socket.assigns.graph

    if graph.domain == "Solar" do
      plot =
        Collector.Solar.insolation_plot(
          graph.items,
          lat_lng,
          graph.from,
          graph.to,
          time_zone: time_zone,
          panel_tilt: 0.0
        )

      assign(socket, :plot, plot)
    else
      assign_data_plot(socket, lat_lng, time_zone)
    end
  end

  defp assign_data_plot(socket, lat_lng, time_zone) do
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
      assign(socket, plot: plot, updated: "Never")
    else
      query =
        case to_utc(graph.from, time_zone) do
          %DateTime{} = from ->
            query |> where([i], i.at >= ^from)

          _ ->
            query
        end

      query =
        case to_utc(graph.to, time_zone) do
          %DateTime{} = to ->
            query |> where([i], i.at <= ^to)

          _ ->
            query
        end

      data =
        query
        |> Collector.Repo.all()

      data =
        if "Incident" in graph.items do
          panel = Panel.new(0.0)
          Enum.map(data, &with_incident_at_local(&1, lat_lng, panel, time_zone))
        else
          Enum.map(data, &at_local(&1, time_zone))
        end

      last_data =
        base_query
        |> last(:at)
        |> Collector.Repo.one()

      updated =
        case to_local(last_data, time_zone) do
          %DateTime{} = local -> Collector.Visual.Graph.strftime(local)
          _ -> "Never"
        end

      plot = Visual.Graph.plot(data, graph.items)
      assign(socket, plot: plot, updated: updated)
    end
  end

  defp to_utc(%NaiveDateTime{} = naive, time_zone) do
    case DateTime.from_naive(naive, time_zone) do
      {:ok, dt} -> Collector.Solar.to_utc(dt)
      _ -> nil
    end
  end

  defp to_utc(_naive, _time_zone), do: nil

  defp to_local(%DateTime{} = dt, time_zone) do
    case Collector.Solar.to_time_zone(dt, time_zone) do
      %DateTime{} = local -> local
      _ -> nil
    end
  end

  defp to_local(%{at: at}, time_zone) do
    to_local(at, time_zone)
  end

  defp to_local(_dt, _time_zone), do: nil

  defp at_local(%Luminosity{at: at} = str, time_zone) do
    str
    |> Luminosity.with_energy()
    |> Map.from_struct()
    |> Map.put(:at, to_local(at, time_zone))
  end

  defp at_local(%{at: at} = str, time_zone) when is_struct(str) do
    str
    |> Map.from_struct()
    |> Map.put(:at, to_local(at, time_zone))
  end

  defp with_incident_at_local(
         %Luminosity{} = luminosity,
         %LatLng{} = lat_lng,
         %Panel{} = panel,
         time_zone
       ) do
    luminosity
    |> Luminosity.with_incident(lat_lng, panel)
    |> at_local(time_zone)
  end

  @impl true
  def handle_info({CollectorWeb.GraphLive.FormComponent, {:saved, graph}}, socket) do
    {:noreply,
     socket
     |> assign_graph(graph)
     |> assign_plot()}
  end

  def handle_info({:data_uploaded, %{domain: domain}}, socket) do
    socket =
      if socket.assigns.graph.domain == domain do
        assign_plot(socket)
      else
        socket
      end

    {:noreply, socket}
  end

  defp page_title(:show), do: "Chart"
  defp page_title(:edit), do: "Edit chart"
end
