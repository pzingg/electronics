defmodule Collector.SolarFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Collector.Solar` context.
  """

  @doc """
  Generate a luminosity.
  """
  def luminosity_fixture(attrs \\ %{}) do
    {:ok, luminosity} =
      attrs
      |> Enum.into(%{
        source_id: 42,
        at: ~U[2024-09-08 17:17:00Z],
        infrared: 42,
        lux: 120.5,
        visible: 42
      })
      |> Collector.Solar.create_luminosity()

    luminosity
  end
end
