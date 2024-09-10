defmodule CollectorWeb.GraphLive.FormComponent do
  use CollectorWeb, :live_component

  require Logger

  alias Collector.Visual

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage graphs in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="graph-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:from]} type="datetime-local" label="From" />
        <.input field={@form[:to]} type="datetime-local" label="To" />
        <.input field={@form[:domain]} type="text" label="Domain" />
        <.input
          field={@form[:items]}
          type="select"
          label="Items"
          options={String.split(@form[:valid_items].value)}
          multiple
        />
        <:actions>
          <.button phx-disable-with="Saving...">Show Graph</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{graph: graph} = assigns, socket) do
    Logger.error("update form #{inspect(graph)}")

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Visual.Graph.changeset(graph))
     end)}
  end

  @impl true
  def handle_event("validate", %{"graph" => graph_params}, socket) do
    changeset = Visual.Graph.changeset(socket.assigns.graph, graph_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"graph" => graph_params}, socket) do
    save_graph(socket, socket.assigns.action, graph_params)
  end

  defp save_graph(socket, :edit, graph_params) do
    updated_graph =
      Visual.Graph.changeset(socket.assigns.graph, graph_params)
      |> Ecto.Changeset.apply_action(:edit)

    case updated_graph do
      {:ok, graph} ->
        notify_parent({:saved, graph})

        {:noreply,
         socket
         |> put_flash(:info, "Graph updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
