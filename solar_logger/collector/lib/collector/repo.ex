defmodule Collector.Repo do
  use Ecto.Repo,
    otp_app: :collector,
    adapter: Ecto.Adapters.Postgres

  def ingest(module, rows) do
    inserted_rows =
      rows
      |> Enum.map(fn row ->
        result =
          struct(module)
          |> module.changeset(row)
          |> Collector.Repo.insert(returning: [:at])

        case result do
          {:ok, inserted} -> inserted.at
          _ -> nil
        end
      end)
      |> Enum.filter(fn row -> !is_nil(row) end)

    {:ok, inserted_rows}
  end
end
