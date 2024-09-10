defmodule SolarCalculationTest do
  # Use the module
  use ExUnit.Case, async: true

  test "line 121" do
    latlng = %Collector.Solar.LatLng{
      latitude: 40.0,
      longitude: -105.0
    }

    # UTC-6 in Central Daylight Time
    dt = DateTime.new!(Date.new!(2010, 6, 21), Time.new!(12, 0, 0), "America/Chicago")

    result = Collector.Solar.calculate(latlng, dt)

    assert_in_delta(result.julian_day, 2_455_369.25, 0.01)
    assert_in_delta(result.radiance_vector, 1.01627236741824, 0.001)
    assert_in_delta(result.right_ascension, 90.2818364620868, 0.001)
    assert result.solar_noon == Time.new!(13, 1, 48)
    assert result.sunrise_time == Time.new!(5, 31, 22)
    assert result.sunset_time == Time.new!(20, 32, 15)
    assert_in_delta(result.sunlight_duration, 900.88207267152, 0.001)
    assert_in_delta(result.solar_elevation, 68.9300623623144, 0.001)
    assert_in_delta(result.solar_azimuth, 137.169999908702, 0.001)
    assert_in_delta(result.solar_energy, 933.1422921157839, 0.001)
  end

  test "kentfield" do
    latlng = %Collector.Solar.LatLng{
      latitude: 37.94,
      longitude: -122.55
    }

    # UTC-8 in Pacific Daylight Time
    dt = DateTime.new!(Date.new!(2024, 9, 10), Time.new!(12, 0, 0), "America/Los_Angeles")

    result = Collector.Solar.calculate(latlng, dt)

    assert_in_delta(result.julian_day, 2_460_564.33, 0.01)
    # assert_in_delta(result.radiance_vector, 1.0067630351311914, 0.001)
    # assert_in_delta(result.right_ascension, 169.51484744015391, 0.001)
    assert result.solar_noon == Time.new!(12, 6, 54)
    assert result.sunrise_time == Time.new!(5, 48, 33)
    assert result.sunset_time == Time.new!(18, 25, 15)
    assert_in_delta(result.sunlight_duration, 756.7078275461419, 0.001)
    # assert_in_delta(result.solar_elevation, 56.54453945414622, 0.001)
    # assert_in_delta(result.solar_azimuth, 176.87476572648632, 0.001)
    # assert_in_delta(result.solar_energy, 834.3146238722336, 0.001)
  end

  test "date range" do
    from = Date.new!(2024, 9, 10)
    to = Date.new!(2024, 9, 11)
    range = Collector.Solar.date_range(from, to)
    assert range == [~D[2024-09-10], ~D[2024-09-11]]
  end

  test "time range" do
    from = 5
    to = 19
    range = Collector.Solar.time_range(from, to, 10)
    assert Enum.count(range) == 85
    assert List.first(range) == ~T[05:00:00]
    assert List.last(range) == ~T[19:00:00]
  end
end
