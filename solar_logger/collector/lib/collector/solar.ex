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

  @doc """
  Formulas taken from an Excel spreadsheet on NOAA's website.

  https://gml.noaa.gov/grad/solcalc/calcdetails.html

  Valid for dates between 1901 and 2099, due to an approximation used
  in the Julian Day calculation. The web calculator does not use this
  approximation, and can report values between the years -2000 and +3000.

  The Julian Day is very close to the value produced by the Timex
  library's `julian_date/6` function.
  """
  def solar_geometry(%LatLng{} = latlng, %DateTime{} = dt) do
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

    %{
      latitude: latitude_b3,
      longitude: longitude_b4,
      time: dt,
      tz_offset: tzoffset_b5,
      julian_day: julian_day_f2,
      radiance_vector: sun_rad_vector_o2,
      right_ascension: sun_rt_ascen_s2,
      solar_noon: time_from_day(solar_noon_x2),
      sunrise_time: time_from_day(sunrise_time_y2),
      sunset_time: time_from_day(sunset_time_z2),
      sunlight_duration: sunlight_duration_aa2,
      solar_elevation: solar_elevation_corrected_for_atm_refraction_ag2,
      solar_azimuth: solar_azimuth_angle_ah2
    }
  end

  @doc """
  Approximates the solar energy in W/m2 perpendicular to the ground
  plane (`solar_energy_incident`) and perpendicular to an arbitrarily
  tilted solar moudule (`solar_energy_module`).

  ## Notes:

  A commonly used value of intensity at sea level is 1000.0 Kw/m2.

  For the average sunlight spectrum there is an approximate conversion
  of 0.0079 W/m2 per Lux.

  ## Air Mass

  From https://www.pveducation.org/pvcdrom/properties-of-sunlight/air-mass

  Air mass is the atmospheric distance that solar rays pass through,
  relative to the distance traveled when the sun is perpendicular to
  the ground plane (zenith angle = 0°). If `alpha` is the sun elevation
  angle in degrees, then `zenith = (90 - alpha)`.

  With 0° <= alpha <= 90° and 0° <= zenith <= 90°:

    `air_mass = 1.0 / cos(zenith)`

  or

    `air_mass = 1.0 / sin(alpha)`

  or taking into account the curvature of the atmosphere:

    `air_mass = 1.0 / ( cos(zenith) + 0.50572 * pow(96.07995 - zenith, -1.6364) )`

  or

    `air_mass = 1.0 / ( sin(alpha) + 0.50572 * pow(6.07995 + alpha, -1.6364) )`

  Finally:

    `s_incident = 1.353 * ( (1.0 - k * h) * pow(0.7, pow(air_mass, 0.678)) + (k * h) )`

  where:

  - `s_incident` is the intensity on a plane perpendicular to the sun's
    rays in units of kW/m2
  - `air_mass` is the air mass
  - 1.353 kW/m2 is the solar constant
  - 0.7 arises from the fact that about 70% of the radiation incident
    on the atmosphere is transmitted to the Earth
  - 0.678 is an empirical fit to the observed data and takes into account
    the non-uniformities in the atmospheric layers
  - `k` = 0.14 is an empirical constant
  - `h` is the location height above sea level in kilometers, 0 <= h <= 3

  ## Intensity on an abritrarily tilted solar module

  From https://www.pveducation.org/pvcdrom/properties-of-sunlight/arbitrary-orientation-and-tilt

  For a solar module at an arbitrary tilt and orientation, the intensity
  on the module is:

    `s_module = s_incident * (cos(alpha) * sin(beta) * cos(psi - theta) + sin(alpha) * cos(beta))`

  where:

  - `s_module` and `s_incident` are respectively the light intensities
    on the module and of the incoming light in W/m², the `s_incident`
    being a direct only component
  - `alpha` is the sun elevation angle
  - `theta` is the sun azimuth angle
  - `beta` is the module tilt angle. A module lying flat on the ground
    has `beta` = 0°, and a vertical module has `beta` = 90°.
  - `psi` is the azimuth angle that the module faces. The vast majority
    of modules are aligned to face towards the equator. A module in the
    southern hemisphere will be facing north with `psi` = 0° and a
    module in the northern hemisphere will typically face directly
    south with `psi` = 180°.

  A module that directly faces the sun so that the incoming rays are
  perpendicular to the module surface has the module tilt equal to the
  sun's zenith angle (`beta = 90 - alpha`), and the module azimuth angle
  equal to the sun's azimuth angle (`psi = theta`).
  """
  def solar_energy(
        %{latitude: latitude, solar_elevation: alpha, solar_azimuth: theta},
        beta \\ nil,
        psi \\ 180.0,
        height \\ 0.0
      ) do
    beta = if is_nil(beta), do: abs(latitude), else: beta
    k = 0.14
    air_mass = 1.0 / (sin(radians(alpha)) + 0.50572 * pow(6.07995 + alpha, -1.6364))
    s_incident = 1353.0 * ((1.0 - k * height) * pow(0.7, pow(air_mass, 0.678)) + k * height)

    s_module =
      s_incident *
        (cos(radians(alpha)) * sin(radians(beta)) * cos(radians(psi - theta)) +
           sin(radians(alpha)) * cos(radians(beta)))

    %{
      solar_energy_incident: s_incident,
      solar_energy_module: s_module
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
    beta = abs(latlng.latitude)

    data =
      for date <- date_range(date_from, date_to),
          time <- time_range(time_from, time_to, interval),
          into: [] do
        case DateTime.new(date, time, time_zone) do
          {:error, _} ->
            nil

          {:gap, _dt1, _dt2} ->
            nil

          {:ambiguous, _dt1, _dt2} ->
            nil

          {:ok, dt} ->
            result = solar_geometry(latlng, dt) |> solar_energy(beta)
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
