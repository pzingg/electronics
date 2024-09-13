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

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc false
  def changeset(luminosity, attrs) do
    luminosity
    |> cast(attrs, [:source_id, :visible, :infrared, :lux, :at, :tag])
    |> validate_required([:source_id, :at])
  end

  def valid_items() do
    ~w(visible infrared lux)
  end
end
