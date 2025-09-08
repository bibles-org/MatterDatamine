options no_aot
require ecs
require math
require game.es.net_console_macro
require game.es.zone_weather_common


[net_console_cmd(name="zone_weather.default")]
def console_zone_weather_default()
  let found = find_query() <| $ [es] (var zone_weather__state : int&)
    zone_weather__state = int(ZoneWeatherState.DEFAULT)
    return true
  if !found
    console_print("zone_weather is not found!")


[net_console_cmd(name="zone_weather.storm")]
def console_zone_weather_storm()
  let found = find_query() <| $ [es] (var zone_weather__state : int&)
    zone_weather__state = int(ZoneWeatherState.STORM)
    return true
  if !found
    console_print("zone_weather is not found!")


[console_cmd(name="zone_weather.test_mode")]
def console_zone_weather_test_mode()
  query() <| $ [es] (var zone_weather_postfx_color_grading__testMode : bool&)
    zone_weather_postfx_color_grading__testMode = true
