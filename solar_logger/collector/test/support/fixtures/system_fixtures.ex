defmodule Collector.SystemFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Collector.System` context.
  """

  @doc """
  Generate a cpu.
  """
  def cpu_fixture(attrs \\ %{}) do
    {:ok, cpu} =
      attrs
      |> Enum.into(%{
        source_id: 42,
        at: ~U[2024-09-08 17:19:00Z],
        guest: 120.5,
        guest_nice: 120.5,
        idle: 120.5,
        iowait: 120.5,
        irq: 120.5,
        nice: 120.5,
        softirq: 120.5,
        steal: 120.5,
        system: 120.5,
        user: 120.5
      })
      |> Collector.System.create_cpu()

    cpu
  end

  @doc """
  Generate a vmemory.
  """
  def vmemory_fixture(attrs \\ %{}) do
    {:ok, vmemory} =
      attrs
      |> Enum.into(%{
        source_id: 42,
        active: 42,
        at: ~U[2024-09-08 17:20:00Z],
        available: 42,
        buffers: 42,
        cached: 42,
        free: 42,
        inactive: 42,
        percent: 120.5,
        shared: 42,
        slab: 42,
        total: 42,
        used: 42
      })
      |> Collector.System.create_vmemory()

    vmemory
  end
end
