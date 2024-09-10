defmodule Collector.VisualFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Collector.Visual` context.
  """

  @doc """
  Generate a graph.
  """
  def graph_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        from: ~N[2024-09-08 21:23:00],
        to: ~N[2024-09-08 21:23:00]
      })

    %Collector.Visual.Graph{}
    |> Collector.Visual.Graph.changeset(attrs)
    |> Ecto.Changeset.apply_changes()
  end
end
