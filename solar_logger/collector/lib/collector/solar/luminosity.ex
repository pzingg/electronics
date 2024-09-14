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

  @doc """
  We use a conversion of 116 lux = 1 W/m2.
  Adding in a fudge factor.

  See notes in the documentation for `Collect.Solar.solar_energy/2`.
  """
  def with_energy(%__MODULE__{lux: lux} = luminosity) when is_float(lux) do
    %__MODULE__{luminosity | energy: lux / 116.0}
  end

  def with_energy(luminosity), do: luminosity

  def with_incident(
        %__MODULE__{at: %DateTime{} = at} = luminosity,
        %LatLng{} = lat_lng,
        %Panel{} = panel
      ) do
    energy =
      Sun.new(lat_lng, at)
      |> Collector.Solar.solar_energy(panel)

    %__MODULE__{luminosity | incident: energy.incident}
  end

  def with_incident(luminosity, _latlng, _panel), do: luminosity

  def valid_items() do
    ~w(Energy Incident Lux Visible Infrared)
  end
end
