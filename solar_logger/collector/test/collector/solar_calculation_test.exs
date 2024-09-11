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

  describe "time range" do
    test "2 hours" do
      from = Time.new!(5, 0, 0)
      to = Time.new!(19, 0, 0)
      range = Collector.Solar.time_range(from, to, {2, :hour})
      assert Enum.count(range) == 8
      assert List.first(range) == ~T[05:00:00]
      assert List.last(range) == ~T[19:00:00]
    end

    test "10 minutes" do
      from = Time.new!(5, 0, 0)
      to = Time.new!(19, 0, 0)
      range = Collector.Solar.time_range(from, to, {10, :minute})
      assert Enum.count(range) == 85
      assert List.first(range) == ~T[05:00:00]
      assert List.last(range) == ~T[19:00:00]
    end

    test "all day 10 minutes" do
      from = Time.new!(0, 0, 0)
      to = Time.new!(23, 59, 59)
      range = Collector.Solar.time_range(from, to, {10, :minute})
      assert Enum.count(range) == 144
      assert List.first(range) == ~T[00:00:00]
      assert List.last(range) == ~T[23:50:00]
    end
  end

  test "to utc" do
    dt = DateTime.new!(Date.new!(2024, 9, 10), Time.new!(12, 0, 0), "America/Los_Angeles")
    utc = Collector.Solar.to_utc(dt)
    assert utc == ~U[2024-09-10 19:00:00Z]
  end

  describe "to time zone" do
    test "unambiguous standard UTC-8" do
      dt = DateTime.new!(Date.new!(2024, 12, 10), Time.new!(9, 0, 0))
      local = Collector.Solar.to_time_zone(dt, "America/Los_Angeles")
      assert local.utc_offset == -28800
      assert local.std_offset == 0
      assert DateTime.to_naive(local) == ~N[2024-12-10 01:00:00]
    end

    test "unambiguous daylight UTC-7" do
      dt = DateTime.new!(Date.new!(2024, 9, 10), Time.new!(9, 0, 0))
      local = Collector.Solar.to_time_zone(dt, "America/Los_Angeles")
      assert local.utc_offset == -28800
      assert local.std_offset == 3600
      assert DateTime.to_naive(local) == ~N[2024-09-10 02:00:00]
    end

    test "spring ahead 1 standard UTC-8" do
      dt = DateTime.new!(Date.new!(2024, 3, 10), Time.new!(9, 59, 59))
      local = Collector.Solar.to_time_zone(dt, "America/Los_Angeles")
      assert local.utc_offset == -28800
      assert local.std_offset == 0
      assert DateTime.to_naive(local) == ~N[2024-03-10 01:59:59]
    end

    test "spring ahead 2 daylight UTC-7" do
      dt = DateTime.new!(Date.new!(2024, 3, 10), Time.new!(10, 0, 0))
      local = Collector.Solar.to_time_zone(dt, "America/Los_Angeles")
      assert local.utc_offset == -28800
      assert local.std_offset == 3600
      assert DateTime.to_naive(local) == ~N[2024-03-10 03:00:00]
    end

    test "fall behind 1 daylight UTC-7" do
      dt = DateTime.new!(Date.new!(2024, 11, 3), Time.new!(8, 59, 59))
      local = Collector.Solar.to_time_zone(dt, "America/Los_Angeles")
      assert local.utc_offset == -28800
      assert local.std_offset == 3600
      assert DateTime.to_naive(local) == ~N[2024-11-03 01:59:59]
    end

    test "fall behind 2 standard UTC-8" do
      dt = DateTime.new!(Date.new!(2024, 11, 3), Time.new!(9, 0, 0))
      local = Collector.Solar.to_time_zone(dt, "America/Los_Angeles")
      assert local.utc_offset == -28800
      assert local.std_offset == 0
      assert DateTime.to_naive(local) == ~N[2024-11-03 01:00:00]
    end
  end
end
