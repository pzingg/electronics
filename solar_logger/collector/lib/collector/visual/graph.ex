defmodule Collector.Visual.Graph do
  use Ecto.Schema
  import Ecto.Changeset

  require Logger

  @plot_height 600
  @plot_width 1000

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
    |> validate_inclusion(:domain, ~w(Cpu Vmemory Luminosity Solar))
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

        "Solar" ->
          ~w(Incident Module)

        other ->
          Logger.error("invalid domain #{other}")
          []
      end

    changeset
    |> put_change(:valid_items, Enum.join(valid_items, " "))
    |> validate_subset(:items, valid_items)
  end

  def domains(), do: ~w(Luminosity Cpu Vmemory)

  def new(attrs \\ %{}) do
    [item | _rest] = Collector.Solar.Luminosity.valid_items()
    changeset(%__MODULE__{domain: "Luminosity", items: [item]}, attrs) |> apply_changes()
  end

  def atomize(items) when is_list(items) do
    Enum.map(items, &atomize(&1))
  end

  def atomize(item) when is_binary(item) do
    item
    |> String.downcase()
    |> String.to_atom()
  end

  def atomize(item) when is_atom(item), do: item

  def strftime(%DateTime{} = date), do: Calendar.strftime(date, "%d-%b-%Y %I:%M:%S %p")
  def strftime(%NaiveDateTime{} = date), do: Calendar.strftime(date, "%d-%b-%Y %I:%M:%S %p")
  def strftime(_), do: ""

  def plot([], _items) do
    "Nothing to plot"
  end

  def plot(data, items) do
    y_cols = atomize(items)

    # Some other things to try:
    # legend_setting: :legend_right,
    # custom_x_scale: timescale,
    data
    |> Contex.Dataset.new()
    |> Contex.Plot.new(
      Contex.LinePlot,
      @plot_width,
      @plot_height,
      smoothed: false,
      mapping: %{
        x_col: :at,
        y_cols: y_cols
      }
    )
    |> Contex.Plot.to_svg()
  end
end
