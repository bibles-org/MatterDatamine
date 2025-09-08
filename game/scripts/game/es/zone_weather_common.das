module zone_weather_common shared
require ecs
require math


enum ZoneWeatherState
  DEFAULT
  STORM
