defmodule Collector.Repo.Migrations.CreateLuminosity do
  use Ecto.Migration

  def change do
    create table(:luminosity) do
      add :source_id, :integer
      add :visible, :integer
      add :infrared, :integer
      add :lux, :float
      add :at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end
  end
end
