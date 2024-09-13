defmodule Collector.Solar.LatLng do
  @enforce_keys [:latitude, :longitude]
  defstruct latitude: nil, longitude: nil

  def new(latitude, longitude) do
    %__MODULE__{latitude: latitude, longitude: longitude}
  end
end
