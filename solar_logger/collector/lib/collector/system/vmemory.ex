defmodule Collector.System.Vmemory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "vmemory" do
    field :source_id, :integer
    field :active, :integer
    field :free, :integer
    field :inactive, :integer
    field :total, :integer
    field :used, :integer
    field :cached, :integer
    field :available, :integer
    field :percent, :float
    field :buffers, :integer
    field :shared, :integer
    field :slab, :integer
    field :at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc false
  def changeset(vmemory, attrs) do
    vmemory
    |> cast(attrs, [
      :source_id,
      :total,
      :available,
      :percent,
      :used,
      :free,
      :active,
      :inactive,
      :buffers,
      :cached,
      :shared,
      :slab,
      :at
    ])
    |> validate_required([:source_id, :at])
  end

  def valid_items() do
    ~w(total available percent used free active inactive buffers cached shared slab)
  end
end
