defmodule Parser do
  use Platform.Parsing.Behaviour

  # ELEMENT IoT Parser for Lobaro LoRaWAN GPS Tracker v5.0
  # According to documentation provided by Lobaro
  # Link: https://www.lobaro.com/portfolio/lorawan-gps-tracker/
  # Documentation: https://www.lobaro.com/download/7315/

  def parse(<<button::big-8, temp::big-16, vbat::big-16, lat_deg::big-8, lat_min::big-8, lat_10000::big-16, long_deg::big-8, long_min::big-8, long_10000::big-16>>, _meta) do

    # calculate the GPS coordinates
    gpslatitude = lat_deg + (lat_min/60) + (lat_10000/600000)
    gpslongitude = long_deg + (long_min/60) + (long_10000/600000)

    # return value map
    {%{
      button: button,  # Pressed Buttons
      temp: temp/10,   # Temperature in °C
      vbat: vbat/1000, # Battery level in V
    },
    [
      location: {gpslongitude, gpslatitude}, # GPS coordinates as GEO Point for showing in map
    ]}
  end
end
