defmodule Collector.Solar.Luminosity do
  use Ecto.Schema
  import Ecto.Changeset

  alias Collector.Solar.{LatLng, Panel, Sun}

  schema "luminosity" do
    field :source_id, :integer
    field :visible, :integer
    field :infrared, :integer
    field :lux, :float
    field :at, :utc_datetime_usec
    field :tag, :string
    field :energy, :float, virtual: true
    field :incident, :float, virtual: true

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc false
  def changeset(luminosity, attrs) do
    luminosity
    |> cast(attrs, [:source_id, :visible, :infrared, :lux, :at, :tag])
    |> validate_required([:source_id, :at])
  end

  def with_energy(%__MODULE__{lux: lux} = luminosity) when is_float(lux) do
    %__MODULE__{luminosity | energy: 0.0079 * lux}
  end

  def with_energy(luminosity), do: luminosity

  def with_incident(
        %__MODULE__{at: %DateTime{} = at} = luminosity,
        %LatLng{} = latlng,
        %Panel{} = panel
      ) do
    energy =
      Sun.new(latlng, at)
      |> Collector.Solar.solar_energy(panel)

    %__MODULE__{luminosity | incident: energy.energy_incident}
  end

  def with_incident(luminosity, _latlng, _panel), do: luminosity

  def valid_items() do
    ~w(lux energy incident visible infrared)
  end
end
