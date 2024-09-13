defmodule Collector.Repo.Migrations.CreateCpu do
  use Ecto.Migration

  def change do
    create table(:cpu) do
      add :source_id, :integer
      add :user, :float
      add :nice, :float
      add :system, :float
      add :idle, :float
      add :iowait, :float
      add :irq, :float
      add :softirq, :float
      add :steal, :float
      add :guest, :float
      add :guest_nice, :float
      add :at, :utc_datetime_usec
      add :tag, :string

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end
  end
end
