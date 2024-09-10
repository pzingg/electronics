defmodule Collector.Repo.Migrations.CreateVmemory do
  use Ecto.Migration

  def change do
    create table(:vmemory) do
      add :source_id, :integer
      add :total, :bigint
      add :available, :bigint
      add :percent, :float
      add :used, :bigint
      add :free, :bigint
      add :active, :bigint
      add :inactive, :bigint
      add :buffers, :bigint
      add :cached, :bigint
      add :shared, :bigint
      add :slab, :bigint
      add :at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end
  end
end
