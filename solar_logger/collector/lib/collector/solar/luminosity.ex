defmodule Collector.Solar.Luminosity do
  use Ecto.Schema
  import Ecto.Changeset

  schema "luminosity" do
    field :source_id, :integer
    field :visible, :integer
    field :infrared, :integer
    field :lux, :float
    field :at, :utc_datetime_usec
    field :tag, :string
    field :energy, :float, virtual: true

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc false
  def changeset(luminosity, attrs) do
    luminosity
    |> cast(attrs, [:source_id, :visible, :infrared, :lux, :at, :tag])
    |> validate_required([:source_id, :at])
  end

  def with_energy(%__MODULE__{lux: lux} = record) when is_float(lux) do
    %__MODULE__{record | energy: 0.0079 * lux}
  end

  def with_energy(record), do: record

  def valid_items() do
    ~w(energy lux visible infrared)
  end
end
