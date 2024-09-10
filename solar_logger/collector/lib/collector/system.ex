defmodule Collector.System do
  @moduledoc """
  The System context.
  """

  import Ecto.Query, warn: false
  alias Collector.Repo

  alias Collector.System.Cpu

  @doc """
  Returns the list of cpu.

  ## Examples

      iex> list_cpu()
      [%Cpu{}, ...]

  """
  def list_cpu do
    Repo.all(Cpu)
  end

  @doc """
  Gets a single cpu.

  Raises `Ecto.NoResultsError` if the Cpu does not exist.

  ## Examples

      iex> get_cpu!(123)
      %Cpu{}

      iex> get_cpu!(456)
      ** (Ecto.NoResultsError)

  """
  def get_cpu!(id), do: Repo.get!(Cpu, id)

  @doc """
  Creates a cpu.

  ## Examples

      iex> create_cpu(%{field: value})
      {:ok, %Cpu{}}

      iex> create_cpu(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_cpu(attrs \\ %{}) do
    %Cpu{}
    |> Cpu.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a cpu.

  ## Examples

      iex> update_cpu(cpu, %{field: new_value})
      {:ok, %Cpu{}}

      iex> update_cpu(cpu, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_cpu(%Cpu{} = cpu, attrs) do
    cpu
    |> Cpu.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a cpu.

  ## Examples

      iex> delete_cpu(cpu)
      {:ok, %Cpu{}}

      iex> delete_cpu(cpu)
      {:error, %Ecto.Changeset{}}

  """
  def delete_cpu(%Cpu{} = cpu) do
    Repo.delete(cpu)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking cpu changes.

  ## Examples

      iex> change_cpu(cpu)
      %Ecto.Changeset{data: %Cpu{}}

  """
  def change_cpu(%Cpu{} = cpu, attrs \\ %{}) do
    Cpu.changeset(cpu, attrs)
  end

  alias Collector.System.Vmemory

  @doc """
  Returns the list of vmemory.

  ## Examples

      iex> list_vmemory()
      [%Vmemory{}, ...]

  """
  def list_vmemory do
    Repo.all(Vmemory)
  end

  @doc """
  Gets a single vmemory.

  Raises `Ecto.NoResultsError` if the Vmemory does not exist.

  ## Examples

      iex> get_vmemory!(123)
      %Vmemory{}

      iex> get_vmemory!(456)
      ** (Ecto.NoResultsError)

  """
  def get_vmemory!(id), do: Repo.get!(Vmemory, id)

  @doc """
  Creates a vmemory.

  ## Examples

      iex> create_vmemory(%{field: value})
      {:ok, %Vmemory{}}

      iex> create_vmemory(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_vmemory(attrs \\ %{}) do
    %Vmemory{}
    |> Vmemory.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a vmemory.

  ## Examples

      iex> update_vmemory(vmemory, %{field: new_value})
      {:ok, %Vmemory{}}

      iex> update_vmemory(vmemory, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_vmemory(%Vmemory{} = vmemory, attrs) do
    vmemory
    |> Vmemory.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a vmemory.

  ## Examples

      iex> delete_vmemory(vmemory)
      {:ok, %Vmemory{}}

      iex> delete_vmemory(vmemory)
      {:error, %Ecto.Changeset{}}

  """
  def delete_vmemory(%Vmemory{} = vmemory) do
    Repo.delete(vmemory)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking vmemory changes.

  ## Examples

      iex> change_vmemory(vmemory)
      %Ecto.Changeset{data: %Vmemory{}}

  """
  def change_vmemory(%Vmemory{} = vmemory, attrs \\ %{}) do
    Vmemory.changeset(vmemory, attrs)
  end
end
