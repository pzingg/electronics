defmodule Collector.Solar.Sun do
  alias Collector.Solar.LatLng

  @enforce_keys [:position, :date]
  defstruct position: nil, date: nil

  def new(%LatLng{} = position, %DateTime{} = date) do
    %__MODULE__{position: position, date: date}
  end
end
