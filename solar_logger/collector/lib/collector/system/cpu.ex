defmodule Collector.System.Cpu do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cpu" do
    field :source_id, :integer
    field :system, :float
    field :user, :float
    field :idle, :float
    field :nice, :float
    field :iowait, :float
    field :irq, :float
    field :softirq, :float
    field :steal, :float
    field :guest, :float
    field :guest_nice, :float
    field :at, :utc_datetime_usec
    field :tag, :string

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc false
  def changeset(cpu, attrs) do
    cpu
    |> cast(attrs, [
      :source_id,
      :user,
      :nice,
      :system,
      :idle,
      :iowait,
      :irq,
      :softirq,
      :steal,
      :guest,
      :guest_nice,
      :at,
      :tag
    ])
    |> validate_required([:source_id, :at])
  end

  def valid_items() do
    ~w(User Nice System Idle Iowait Irq Softirq Steal Guest Guest_Nice)
  end
end
