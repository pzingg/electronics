defmodule Collector.Solar do
  @moduledoc """
  The Solar context.
  """

  require Logger

  import :math
  import Ecto.Query, warn: false

  alias Collector.Repo
  alias Collector.Solar.{LatLng, Luminosity, Panel, Sun}

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
    {h, day_offset} = {Integer.mod(h, 24), div(h, 24)}

    case Time.new(h, m, s) do
      {:ok, time} ->
        {time, day_offset}

      {:error, _reason} ->
        Logger.error("Cannot build time #{h}:#{m}:#{s} from #{t}")
        nil
    end
  end

  defmodule GeometryData do
    defstruct latitude: nil,
              longitude: nil,
              time: nil,
              tz_offset: nil,
              julian_day: nil,
              radiance_vector: nil,
              right_ascension: nil,
              declination: nil,
              solar_noon: nil,
              sunrise_time: nil,
              sunset_time: nil,
              sunlight_duration: nil,
              solar_elevation: nil,
              solar_azimuth: nil
  end

  defmodule EnergyData do
    defstruct incident: nil,
              module: nil
  end

  @doc """
  Formulas taken from an Excel spreadsheet on NOAA's website.

  https://gml.noaa.gov/grad/solcalc/calcdetails.html

  Valid for dates between 1949 and 2050.

  ## Arguments

  - `lat_lng` the location coordinates
  - `dt` the date and time

  ## Returns

  A `GeometryData` struct with these values:

  - `:latitude` - the latitude supplied as an argument in degrees
  - `:longitude` - the longitude supplied as an argument in degrees
  - `:time` - the `DateTime` value supplied as an argument
  - `:tz_offset` - the offset from UTC in hours
  - `:julian_day` - the Julian Day number
  - `:radiance_vector` - a factor indicating the intensity strength
  - `:right_ascension` -  the angle in degrees of the Sun's position
    measured eastward along the celestial equator from the Sun at
    the March equinox
  - `:declination` - the angle in degrees measured north (positive)
    or south (negative) from the celestial equator
  - `:solar_noon` - the time of highest sun as a `NaiveDateTime`
  - `:sunrise_time` - the time of sunrise as a `NaiveDateTime`
  - `:sunset_time` - the time of sunset as a `NaiveDateTime`
  - `:sunlight_duration` - the number of minutes of sunlight
  - `:solar_elevation` - the elevation angle in degrees
  - `:solar_azimuth` - the azimuth angle in degrees

  `:solar_noon`, `:sunrise_time`, and `:sunset_time` are
  returned as tuples. The first element is the `Time` struct, and
  the second element is 0 or 1, the day offset.
  """
  def solar_geometry(%Sun{position: lat_lng, date: dt}) do
    latitude_b3 = lat_lng.latitude
    longitude_b4 = lat_lng.longitude
    tz_offset_b5 = (dt.utc_offset + dt.std_offset) / 3600.0
    time_e2 = (dt.hour + dt.minute / 60.0 + dt.second / 3600.0) / 24.0
    julian_day_f2 = julian_date(dt)
    julian_century_g2 = (julian_day_f2 - 2_451_545.0) / 36525.0

    # Mean longitude and anomaly
    # Michalsky, J. 1988. The Astronomical Almanac's algorithm for
    #   approximate solar position (1950-2050).
    #   Solar Energy 40 (3), pp. 227-235.
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

    solar_noon_x2 = (720.0 - 4.0 * longitude_b4 - eq_of_time_v2 + 60.0 * tz_offset_b5) / 1440.0
    sunrise_time_y2 = solar_noon_x2 - ha_sunrise_w2 * 4.0 / 1440.0
    sunset_time_z2 = solar_noon_x2 + ha_sunrise_w2 * 4.0 / 1440.0
    sunlight_duration_aa2 = 8.0 * ha_sunrise_w2

    true_solar_time_ab2 =
      fmod(time_e2 * 1440.0 + eq_of_time_v2 + 4.0 * longitude_b4 - 60.0 * tz_offset_b5, 1440.0)

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

    # limit the degrees below the horizon to 9 [+90 -> 99]
    solar_zenith_angle_ad2 = min(solar_zenith_angle_ad2, 99.0)

    solar_elevation_angle_ae2 = 90.0 - solar_zenith_angle_ad2

    tanre = tan(radians(solar_elevation_angle_ae2))

    # Refraction correction, degrees
    # Zimmerman, John C. 1981. Sun-pointing programs and their accuracy.
    #   SAND81-0761, Experimental Systems Operation Division 4721,
    #   Sandia National Laboratories, Albuquerque, NM.
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

    %GeometryData{
      latitude: latitude_b3,
      longitude: longitude_b4,
      time: dt,
      tz_offset: tz_offset_b5,
      julian_day: julian_day_f2,
      radiance_vector: sun_rad_vector_o2,
      right_ascension: sun_rt_ascen_s2,
      declination: sun_declin_t2,
      solar_noon: time_from_day(solar_noon_x2),
      sunrise_time: time_from_day(sunrise_time_y2),
      sunset_time: time_from_day(sunset_time_z2),
      sunlight_duration: sunlight_duration_aa2,
      solar_elevation: solar_elevation_corrected_for_atm_refraction_ag2,
      solar_azimuth: solar_azimuth_angle_ah2
    }
  end

  @doc """
  Calculate Julian Date per SOLPOS.
  See https://github.com/gurre/nrel-solpos-2.0/blob/master/solpos.c#L465
  """
  def julian_date(dt) do
    # Michalsky, J. 1988. The Astronomical Almanac's algorithm for
    #   approximate solar position (1950-2050).  Solar Energy 40 (3), pp. 227-235.
    dt_utc = to_utc(dt)
    delta = dt_utc.year - 1949

    if delta < 1 || delta > 101 do
      raise RuntimeError, "Only valid for UTC years 1950 to 2050"
    end

    leap_days = trunc(delta / 4.0)
    date_utc = DateTime.to_date(dt)
    day_num = Date.diff(date_utc, Date.new!(dt_utc.year, 1, 1)) + 1
    partial_day = (dt_utc.hour + dt_utc.minute / 60.0 + dt_utc.second / 3600.0) / 24.0
    2_432_916.5 + delta * 365.0 + leap_days + day_num + partial_day
  end

  # Extra-terrestrial raditaion, could be 1353.0, or a lower value.
  @solar_etr 1353.0

  @doc """
  Approximates the solar energy in W/m2 perpendicular to the ground
  plane (`:incident`) and perpendicular to an arbitrarily
  tilted solar moudule (`:module`).

  ## Arguments

  - `:params` is either a `Sun`, or a `GeometryData` struct as returned from
    `Collector.Solar.solar_geometry/1`. If the latter, the data
    must contain `:latitude`, `:solar_elevation` and `:solar_azimuth`.
  - `:panel` a `Panel` struct describing the orientation of a solar panel,
    where:

  - `:tilt` is the tilt angle of the solar panel in degrees. If
    omitted, the absolute value of latitude is used.
  - `:azimuth` is the compass direction that the solar panel
    faces, in degrees. If omitted, 0.0 is used for southern latitudes and
    180.0 is used for northern latitudes
  - `:altitude` is the location altitude above sea level in kM.
    (default 0.0).

  ## Returns

  An `EnergyData` struct with two values, `:incident` and `:module`.

  ## Notes

  We could use 1353 W/m2 as the value of extra-terrestrial radiation,
  or `etr`, but we will use 1000 to get closer to the values recorded
  by our sensor.

  We use a conversion of 116 lux = 1 W/m2.

  See P. R. Michael, D. E. Johnston, and W. Moreno, “A conversion guide:
    solar irradiance and lux illuminance,”
    Journal of Measurements in Engineering, Vol. 8, No. 4, pp. 153–166, Dec. 2020
    https://doi.org/10.21595/jme.2020.21667

  Datasheet and designer notes on the TSL2591 sensor can be found at:
  https://ams-osram.com/products/sensors/ambient-light-color-spectral-proximity-sensors/ams-tsl25911-ambient-light-sensor#tab/documents

  AN000173 describes lux equations for the TSL2591
  AN000170 and AN000172 also relate to lux calculations
  AN000167 describes the differences between lux and W/m2

  The TSL2591 datasheet (page 6) indicates the following conversions
  from counts to uW/cm2.

  From the Adafruit C++ library at
  https://github.com/adafruit/Adafruit_TSL2591_Library/blob/master/Adafruit_TSL2591.cpp

  ```
  full = (ch1_counts << 16) | ch0_counts
  infrared = ch1_counts
  visible = ((ch1_counts << 16) | ch0_counts) - ch1_counts
  ```

  or inverting:

  ```
  full = visible + infrared
  ch0_counts = (full & 0xFFFF)
  ch1_counts = (full >> 16) & 0xFFFF = infrared
  ```

  Then irradiance conversion for (100ms integration time and 9876x gain) is:

  - White light CHO: 6024 counts / uW/cm2
  - White light CH1: 1003 counts / uW/cm2
  - 850 nM CHO: 5338 counts / uW/cm2
  - 850 nM CH1: 3474 counts / uW/cm2

  and for conversion: 1 uW/cm2 = 0.01 W/m2

  Example for the maximum `visible` and `infrared` counts on a sunny fall day,
  with 100ms integration time and 1x gain:

  lux        =  65619.94
  visible    = 829841019
  infrared   =     12662
  full       = 829853681
  ch0_counts =     36849 # full & 0xFFFF
  ch1_counts =     12662 # (full >> 16) & 0xFFFF, or infrared

  ((visible + infrared) >> 16) as ch1

  w_m2_ch0 = 0.01 * (ch0 / 6024.0) * (9876.0 / gain) * (100.0 / int_time_ms)
           = 1.639442231075697 * ch0 / (gain * int_time_ms)
           = 1.639442231075697 * 36849.0 / 100.0
           = 604.1
  w_m2_ch1 = (ch1 / 1003.0) * (9876.0 / gain) * (100.0 / int_time_ms)
           = 9.846460618145563 * ch1 / (gain * int_time_ms)
           = 9.846460618145563 * 12662.0 / 100.0
           = 1207.4
  w_m2_lux = 65619.94 / 116.0
           = 565.7

  See https://cdn-shop.adafruit.com/datasheets/TSL25911_Datasheet_EN_v1.pdf

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

    `s_incident = etr * ( (1.0 - k * h) * pow(0.7, pow(air_mass, 0.678)) + (k * h) )`

  where:

  - `s_incident` is the intensity on a plane perpendicular to the sun's
    rays in units of kW/m2
  - `air_mass` is the air mass
  - `etr` is the extra-terrestrial solar radiation (1000 or 1353 W/m2)
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
        params,
        panel \\ %Panel{}
      )

  def solar_energy(
        %Sun{} = sun,
        %Panel{} = panel
      ) do
    solar_geometry(sun)
    |> solar_energy(panel)
  end

  def solar_energy(
        %{solar_elevation: solar_elevation},
        _panel
      )
      when solar_elevation <= 0.0 do
    %EnergyData{incident: 0.0, module: 0.0}
  end

  def solar_energy(
        %{solar_elevation: solar_elevation, solar_azimuth: solar_azimuth, latitude: latitude},
        %Panel{tilt: panel_tilt, azimuth: panel_azimuth, altitude: altitude}
      ) do
    panel_tilt = if is_nil(panel_tilt), do: abs(latitude), else: panel_tilt

    panel_azimuth =
      case {panel_azimuth, latitude < 0.0} do
        {_nil, true} -> 0.0
        {_nil, false} -> 180.0
        _ -> panel_azimuth
      end

    k = 0.14
    am = air_mass(solar_elevation)
    s_incident = @solar_etr * ((1.0 - k * altitude) * pow(0.7, pow(am, 0.678)) + k * altitude)

    s_module =
      s_incident *
        module_orientation_factor(solar_elevation, solar_azimuth, panel_tilt, panel_azimuth)

    %EnergyData{
      incident: s_incident,
      module: s_module
    }
  end

  def air_mass(solar_elevation) do
    # Airmass
    # Kasten, F. and Young, A. 1989. Revised optical air mass tables
    #   and approximation formula.
    #   Applied Optics 28 (22), pp. 4735-4738
    1.0 / (sin(radians(solar_elevation)) + 0.50572 * pow(6.07995 + solar_elevation, -1.6364))
  end

  def module_orientation_factor(solar_elevation, solar_azimuth, panel_tilt, panel_azimuth) do
    cos(radians(solar_elevation)) * sin(radians(panel_tilt)) *
      cos(radians(panel_azimuth - solar_azimuth)) +
      sin(radians(solar_elevation)) * cos(radians(panel_tilt))
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

  @doc """
  Makes a line plot of solar energy.

  `items` is a list of atoms to plot, either one or two of the atoms
  `:incident` and `:module` returned by `Collector.solar.solar_energy/2`.

  `opts` is a keyword list of plot and panel options:

  - `:time_zone` is the time zone to apply.
  - `:interval` is the time interval between points, a tuple of
    `{amount, unit}` where unit is `:hour` or `:minute`.
  - `:panel_tilt` is the tilt angle of the solar panel in degrees
  - `:panel_azimuth` is the compass direction that the solar panel
     faces, in degrees (usually 0.0 for southern latitudes and 180.0
     for northern latitudes)
  - `:altitude` is the location altitude above sea level in kM.
  """
  def insolation_plot(
        items,
        lat_lng,
        from,
        to,
        opts \\ []
      )

  def insolation_plot(
        items,
        %LatLng{} = lat_lng,
        %NaiveDateTime{} = from,
        %NaiveDateTime{} = to,
        opts
      ) do
    date_from = NaiveDateTime.to_date(from)
    time_from = NaiveDateTime.to_time(from)
    date_to = NaiveDateTime.to_date(to)
    time_to = NaiveDateTime.to_time(to)

    panel_tilt = Keyword.get(opts, :panel_tilt)
    panel_azimuth = Keyword.get(opts, :panel_azimuth)
    altitude = Keyword.get(opts, :altitude, 0.0)
    panel = Panel.new(panel_tilt, panel_azimuth, altitude)

    time_zone = Keyword.get(opts, :time_zone, "Etc/UTC")
    interval = Keyword.get(opts, :interval, {10, :minute})
    items = Collector.Visual.Graph.atomize(items)

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
            result =
              Sun.new(lat_lng, dt)
              |> solar_energy(panel)

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
        _opts
      ) do
    Collector.Visual.Graph.plot([], items)
  end
end
