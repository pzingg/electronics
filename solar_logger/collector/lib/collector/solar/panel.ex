defmodule Collector.Solar.Panel do
  defstruct tilt: 0.0, azimuth: nil, altitude: 0.0

  def new(tilt, azimuth \\ nil, altitude \\ 0.0) do
    %__MODULE__{tilt: tilt, azimuth: azimuth, altitude: altitude}
  end
end
