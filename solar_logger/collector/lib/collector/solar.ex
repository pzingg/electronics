defmodule Collector.Solar do
  @moduledoc """
  The Solar context.
  """

  import :math
  import Ecto.Query, warn: false

  alias Collector.Repo

  alias Collector.Solar.Luminosity

  @doc """
  Returns the list of luminosity.

  ## Examples

      iex> list_luminosity()
      [%Luminosity{}, ...]

  """
  def list_luminosity do
    Repo.all(Luminosity)
  end

  @doc """
  Gets a single luminosity.

  Raises `Ecto.NoResultsError` if the Luminosity does not exist.

  ## Examples

      iex> get_luminosity!(123)
      %Luminosity{}

      iex> get_luminosity!(456)
      ** (Ecto.NoResultsError)

  """
  def get_luminosity!(id), do: Repo.get!(Luminosity, id)

  @doc """
  Creates a luminosity.

  ## Examples

      iex> create_luminosity(%{field: value})
      {:ok, %Luminosity{}}

      iex> create_luminosity(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_luminosity(attrs \\ %{}) do
    %Luminosity{}
    |> Luminosity.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a luminosity.

  ## Examples

      iex> update_luminosity(luminosity, %{field: new_value})
      {:ok, %Luminosity{}}

      iex> update_luminosity(luminosity, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_luminosity(%Luminosity{} = luminosity, attrs) do
    luminosity
    |> Luminosity.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a luminosity.

  ## Examples

      iex> delete_luminosity(luminosity)
      {:ok, %Luminosity{}}

      iex> delete_luminosity(luminosity)
      {:error, %Ecto.Changeset{}}

  """
  def delete_luminosity(%Luminosity{} = luminosity) do
    Repo.delete(luminosity)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking luminosity changes.

  ## Examples

      iex> change_luminosity(luminosity)
      %Ecto.Changeset{data: %Luminosity{}}

  """
  def change_luminosity(%Luminosity{} = luminosity, attrs \\ %{}) do
    Luminosity.changeset(luminosity, attrs)
  end

  ## Calculations per https://gml.noaa.gov/grad/solcalc/calcdetails.html

  defp radians(a) do
    a * pi() / 180.0
  end

  defp degrees(a) do
    a * 180.0 / pi()
  end

  defp time_from_day(t) do
    h = trunc(t * 24.0)
    m = trunc(t * 1440.0 - h * 60.0)
    s = trunc(t * 86400.0 - h * 3600.0 - m * 60.0)
    Time.new!(h, m, s)
  end

  # Not sure why we are off by two days.
  # MS Excel's epoch should be 1900-01-01
  @epoch Date.new!(1899, 12, 30)

  defmodule LatLng do
    defstruct latitude: nil, longitude: nil
  end

  def calculate(%LatLng{} = latlng, %DateTime{} = dt, irradiance \\ 1000) do
    latitude_b3 = latlng.latitude
    longitude_b4 = latlng.longitude
    tzoffset_b5 = (dt.utc_offset + dt.std_offset) / 3600.0
    date_b7 = Date.diff(DateTime.to_date(dt), @epoch)
    time_e2 = (dt.hour + dt.minute / 60.0 + dt.second / 3600.0) / 24.0
    julian_day_f2 = date_b7 + 2_415_018.5 + time_e2 - tzoffset_b5 / 24.0
    julian_century_g2 = (julian_day_f2 - 2_451_545.0) / 36525.0

    geom_mean_long_sun_i2 =
      fmod(
        280.46646 + julian_century_g2 * (36000.76983 + julian_century_g2 * 0.0003032),
        360
      )

    geom_mean_anom_sun_j2 =
      357.52911 + julian_century_g2 * (35999.05029 - 0.0001537 * julian_century_g2)

    eccent_earth_orbit_k2 =
      0.016708634 - julian_century_g2 * (0.000042037 + 0.0000001267 * julian_century_g2)

    s1 = sin(radians(geom_mean_anom_sun_j2))
    s2 = sin(radians(2.0 * geom_mean_anom_sun_j2))
    s3 = sin(radians(3.0 * geom_mean_anom_sun_j2))

    sun_eq_of_ctr_l2 =
      s1 * (1.914602 - julian_century_g2 * (0.004817 + 0.000014 * julian_century_g2)) +
        s2 * (0.019993 - 0.000101 * julian_century_g2) +
        s3 * 0.000289

    sun_true_long_m2 = geom_mean_long_sun_i2 + sun_eq_of_ctr_l2
    sun_true_anom_n2 = geom_mean_anom_sun_j2 + sun_eq_of_ctr_l2

    sun_rad_vector_o2 =
      1.000001018 * (1 - eccent_earth_orbit_k2 * eccent_earth_orbit_k2) /
        (1 + eccent_earth_orbit_k2 * cos(radians(sun_true_anom_n2)))

    sun_app_long_p2 =
      sun_true_long_m2 - 0.00569 -
        0.00478 * sin(radians(125.04 - 1934.136 * julian_century_g2))

    mean_obliq_ecliptic_q2 =
      23.0 +
        (26.0 +
           (21.448 -
              julian_century_g2 *
                (46.815 + julian_century_g2 * (0.00059 - julian_century_g2 * 0.001813))) / 60.0) /
          60.0

    obliq_corr_r2 =
      mean_obliq_ecliptic_q2 + 0.00256 * cos(radians(125.04 - 1934.136 * julian_century_g2))

    r_lng = radians(sun_app_long_p2)
    r_obl = radians(obliq_corr_r2)

    sun_rt_ascen_s2 = degrees(atan2(cos(r_obl) * sin(r_lng), cos(r_lng)))
    sun_declin_t2 = degrees(asin(sin(r_obl) * sin(r_lng)))

    tan_obl2 = tan(radians(obliq_corr_r2 / 2))
    var_y_u2 = tan_obl2 * tan_obl2

    r_mln = radians(geom_mean_long_sun_i2)
    r_man = radians(geom_mean_anom_sun_j2)

    eq_of_time_v2 =
      4.0 *
        degrees(
          var_y_u2 * sin(2.0 * r_mln) -
            2.0 * eccent_earth_orbit_k2 * sin(r_man) +
            4.0 * eccent_earth_orbit_k2 * var_y_u2 * sin(r_man) * cos(2.0 * r_mln) -
            0.5 * var_y_u2 * var_y_u2 * sin(4.0 * r_mln) -
            1.25 * eccent_earth_orbit_k2 * eccent_earth_orbit_k2 * sin(2.0 * r_man)
        )

    r_lat = radians(latitude_b3)
    r_dec = radians(sun_declin_t2)

    ha_sunrise_w2 =
      degrees(
        acos(
          cos(radians(90.833)) / (cos(r_lat) * cos(r_dec)) -
            tan(r_lat) * tan(r_dec)
        )
      )

    solar_noon_x2 = (720.0 - 4.0 * longitude_b4 - eq_of_time_v2 + tzoffset_b5 * 60.0) / 1440.0
    sunrise_time_y2 = solar_noon_x2 - ha_sunrise_w2 * 4.0 / 1440.0
    sunset_time_z2 = solar_noon_x2 + ha_sunrise_w2 * 4.0 / 1440.0
    sunlight_duration_aa2 = 8.0 * ha_sunrise_w2

    true_solar_time_ab2 =
      fmod(time_e2 * 1440.0 + eq_of_time_v2 + 4.0 * longitude_b4 - 60.0 * tzoffset_b5, 1440.0)

    hour_angle_ac2 =
      if true_solar_time_ab2 / 4.0 < 0 do
        true_solar_time_ab2 / 4.0 + 180.0
      else
        true_solar_time_ab2 / 4.0 - 180.0
      end

    solar_zenith_angle_ad2 =
      degrees(
        acos(
          sin(r_lat) * sin(r_dec) +
            cos(r_lat) * cos(r_dec) *
              cos(radians(hour_angle_ac2))
        )
      )

    solar_elevation_angle_ae2 = 90.0 - solar_zenith_angle_ad2

    tanre = tan(radians(solar_elevation_angle_ae2))

    approx_atmospheric_refraction_af2 =
      cond do
        solar_elevation_angle_ae2 > 85.0 ->
          0.0

        solar_elevation_angle_ae2 > 5.0 ->
          58.1 / tanre - 0.07 / pow(tanre, 3) + 0.000086 / pow(tanre, 5)

        solar_elevation_angle_ae2 > -0.575 ->
          1735.0 +
            solar_elevation_angle_ae2 *
              (-518.2 +
                 solar_elevation_angle_ae2 *
                   (103.4 +
                      solar_elevation_angle_ae2 * (-12.79 + solar_elevation_angle_ae2 * 0.711)))

        true ->
          -20.772 / tanre
      end

    approx_atmospheric_refraction_af2 = approx_atmospheric_refraction_af2 / 3600.0

    solar_elevation_corrected_for_atm_refraction_ag2 =
      solar_elevation_angle_ae2 + approx_atmospheric_refraction_af2

    r_zen = radians(solar_zenith_angle_ad2)

    solar_azimuth_angle_ah2 =
      if hour_angle_ac2 > 0.0 do
        fmod(
          degrees(acos((sin(r_lat) * cos(r_zen) - sin(r_dec)) / (cos(r_lat) * sin(r_zen)))) +
            180.0,
          360.0
        )
      else
        fmod(
          540.0 -
            degrees(acos((sin(r_lat) * cos(r_zen) - sin(r_dec)) / (cos(r_lat) * sin(r_zen)))),
          360.0
        )
      end

    incidence_factor = max(sin(radians(solar_elevation_corrected_for_atm_refraction_ag2)), 0.0)
    solar_energy = irradiance * incidence_factor

    %{
      julian_day: julian_day_f2,
      radiance_vector: sun_rad_vector_o2,
      right_ascension: sun_rt_ascen_s2,
      solar_noon: time_from_day(solar_noon_x2),
      sunrise_time: time_from_day(sunrise_time_y2),
      sunset_time: time_from_day(sunset_time_z2),
      sunlight_duration: sunlight_duration_aa2,
      solar_elevation: solar_elevation_corrected_for_atm_refraction_ag2,
      solar_azimuth: solar_azimuth_angle_ah2,
      solar_energy: solar_energy
    }
  end

  def date_range(date_from, date_to) do
    days = Date.diff(date_to, date_from)
    Enum.map(0..days, &Date.add(date_from, &1))
  end

  def time_range(time_from, time_to, {hours, :hour}) do
    total_hours = time_to.hour - time_from.hour
    steps = div(total_hours, hours)
    Enum.map(0..steps, fn step -> Time.add(time_from, step * hours, :hour) end)
  end

  def time_range(time_from, time_to, {minutes, :minute}) do
    total_minutes = time_to.hour * 60 + time_to.minute - (time_from.hour * 60 + time_from.minute)
    steps = div(total_minutes, minutes)
    Enum.map(0..steps, fn step -> Time.add(time_from, step * minutes, :minute) end)
  end

  defmodule AmbiguousDateTime do
    @enforce_keys [:before, :after, :type]
    defstruct before: nil, after: nil, type: nil
  end

  @doc """
  Convert a date to the given time zone. From `Timex.convert/2`.
  """
  def to_time_zone(%DateTime{time_zone: time_zone} = date, time_zone) do
    # Do not convert date when already in destination time zone
    date
  end

  def to_time_zone(%DateTime{} = date, time_zone) do
    with {:ok, datetime} <- DateTime.shift_zone(date, time_zone) do
      datetime
    else
      {ty, a, b} when ty in [:gap, :ambiguous] ->
        %AmbiguousDateTime{before: a, after: b, type: ty}

      {:error, _} = err ->
        err
    end
  end

  def to_time_zone(%NaiveDateTime{} = date, time_zone) do
    with {:ok, datetime} <- DateTime.from_naive(date, time_zone) do
      datetime
    else
      {ty, a, b} when ty in [:gap, :ambiguous] ->
        %AmbiguousDateTime{before: a, after: b, type: ty}

      {:error, _} = err ->
        err
    end
  end

  def to_utc(date), do: to_time_zone(date, "Etc/UTC")

  def insolation_plot(
        items,
        latlng,
        from,
        to,
        time_zone \\ "Etc/UTC",
        interval \\ {10, :minute}
      )

  def insolation_plot(
        items,
        %LatLng{} = latlng,
        %NaiveDateTime{} = from,
        %NaiveDateTime{} = to,
        time_zone,
        interval
      ) do
    date_from = NaiveDateTime.to_date(from)
    time_from = NaiveDateTime.to_time(from)
    date_to = NaiveDateTime.to_date(to)
    time_to = NaiveDateTime.to_time(to)

    data =
      for date <- date_range(date_from, date_to),
          time <- time_range(time_from, time_to, interval),
          into: [] do
        case DateTime.new(date, time, time_zone) do
          {:error, _} ->
            nil

          {:gap, dt1, dt2} ->
            nil

          {:ambiguous, dt1, dt2} ->
            nil

          {:ok, dt} ->
            result = calculate(latlng, dt)
            Map.take(result, items) |> Map.put(:at, dt)
        end
      end

    data = Enum.filter(data, &is_map(&1))
    Collector.Visual.Graph.plot(data, items)
  end

  def insolation_plot(
        items,
        _latlng,
        _from,
        _to,
        _timezone,
        _interval_mins
      ) do
    Collector.Visual.Graph.plot([], items)
  end
end
