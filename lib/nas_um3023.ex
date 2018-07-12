defmodule Parser do
  use Platform.Parsing.Behaviour

  # ELEMENT IoT Parser for NAS "Pulse + Analog Reader UM3023"  v0.5.0
  # Author NKlein
  # Link: https://www.nasys.no/product/lorawan-pulse-analog-reader/
  # Documentation: https://www.nasys.no/wp-content/uploads/Pulse-Analog-Reader_UM3023.pdf

  # Status Message
  def parse(<<settings, battery::unsigned, temp::signed, rssi::signed, interface_status::binary>>, %{meta: %{frame_port:  24}}) do
    map = %{
      battery: battery,
      temp: temp,
      rssi: rssi,
    }
    parseReporting(settings, interface_status)
    |> Map.merge(map)

  end

  # Status Message
  def parse(<<settings, interface_status::binary>>, %{meta: %{frame_port:  25}}) do
    parseReporting(settings, interface_status)
  end

  # Boot Message
  def parse(<<0x00, serial::4-binary, firmware::3-binary, reset_reason>>, %{meta: %{frame_port:  99}}) do
    %{
      type: :boot,
      serial: Base.encode16(serial),
      firmware: Base.encode16(firmware),
      reset_reason: reset_reason,
    }
  end
  # Shutdown Message
  def parse(<<0x01>>, %{meta: %{frame_port:  99}}) do
    %{
      type: :shutdown,
    }
  end
  # Error Code Message
  def parse(<<0x10, error_code>>, %{meta: %{frame_port:  99}}) do
    %{
      type: :error,
      error_code: error_code,
    }
  end

  # Catchall for any other message.
  def parse(payload, %{meta: %{frame_port:  frame_port}}) do
    %{
      error: "unparseable_message",
      payload: Base.encode16(payload),
      meta_frame_port: frame_port,
    }
  end

  def parseReporting(settings, interface_status) do
    <<_rfu::1, user_triggered::1, mbus::1, ssi::1, analog2_reporting::1, analog1_reporting::1, digital2_reporting::1, digital1_reporting::1>> = <<settings>>
    map = %{
      user_triggered: (1 == user_triggered),
      mbus: (1 == mbus),
      ssi: (1 == ssi)
    }

    reportingKeys = Enum.filter([digital1_reporting: digital1_reporting, digital2_reporting: digital2_reporting, analog1_reporting: analog1_reporting, analog2_reporting: analog2_reporting], fn {_,y} -> y == 1 end)
    |> Enum.map(&elem(&1,0))

    reportings = Enum.zip(reportingKeys,(for <<x::40 <- interface_status >>, do: <<x::40>>))
    |> Enum.map(&_parseReporting/1)
    |> Enum.reduce(map, &Map.merge/2)
  end

  def _parseReporting({type, <<settings::8, counter::little-32>>}) when type in [:digital1_reporting, :digital2_reporting] do
    <<medium_type::4, _rfu::1, trigger_alert::1, trigger_mode::1, value_high::1>> = <<settings>>
    %{
      type => counter,
      "#{type}_medium_type" => medium_type(medium_type),
      "#{type}_trigger_alert" => %{0=>:ok, 1=>:alert}[trigger_alert],
      "#{type}_trigger_mode2" => %{0=>:disabled, 1=>:enabled}[trigger_mode],
      "#{type}_value_during_reporting" => %{0=>:low, 1=>:high}[value_high],
    }
  end

  def _parseReporting({type, <<status_settings, current_value::16-little, avg_value::16-little>>}) when type in [:analog1_reporting, :analog2_reporting] do
    <<_rfu::7, mode::1>> = <<status_settings>>
    %{
      "#{type}_mode" => %{0=>"0..10V", 1=>"4..20mA"}[mode],
      "#{type}_current_value" => current_value,
      "#{type}_average_value" => avg_value,
    }
  end

  def medium_type(0x00), do: :pulses
  def medium_type(0x01), do: :water_in_liter
  def medium_type(0x02), do: :electricity_in_wh
  def medium_type(0x03), do: :gas_in_liter
  def medium_type(0x04), do: :heat_in_wh
  def medium_type(_),    do: :rfu
end
