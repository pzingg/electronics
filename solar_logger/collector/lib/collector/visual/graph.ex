defmodule Collector.Visual.Graph do
  use Ecto.Schema
  import Ecto.Changeset

  require Logger

  embedded_schema do
    field :from, :naive_datetime
    field :to, :naive_datetime
    field :domain, :string
    field :items, {:array, :string}
    field :valid_items, :string
  end

  @doc false
  def changeset(graph, attrs \\ %{}) do
    graph
    |> cast(attrs, [:from, :to, :domain, :items])
    |> validate_required([:domain, :items])
    |> validate_inclusion(:domain, ~w(Cpu Vmemory Luminosity))
    |> validate_items()
  end

  def validate_items(changeset) do
    valid_items =
      case get_field(changeset, :domain) do
        "Cpu" ->
          Collector.System.Cpu.valid_items()

        "Vmemory" ->
          Collector.System.Vmemory.valid_items()

        "Luminosity" ->
          Collector.Solar.Luminosity.valid_items()

        other ->
          Logger.error("invalid domain #{other}")
          []
      end

    changeset
    |> put_change(:valid_items, Enum.join(valid_items, " "))
    |> validate_subset(:items, valid_items)
  end

  def new(attrs) do
    changeset(%__MODULE__{domain: "Cpu", items: ["user", "system"]}, attrs) |> apply_changes()
  end

  def atomize(item) when is_atom(item), do: item
  def atomize(item) when is_binary(item), do: String.to_atom(item)

  def plot([], _items) do
    "Nothing to plot"
  end

  def plot(data, items) do
    y_cols = Enum.map(items, &atomize(&1))

    data
    |> Contex.Dataset.new()
    |> Contex.Plot.new(
      Contex.LinePlot,
      600,
      400,
      # legend_setting: :legend_right,
      # custom_x_scale: timescale,
      smoothed: false,
      mapping: %{
        x_col: :at,
        y_cols: y_cols
      }
    )
    |> Contex.Plot.to_svg()
  end
end
