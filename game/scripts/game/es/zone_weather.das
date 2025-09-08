require ecs
require math
require net
require DagorMath
require DagorSystem
require game.events.events_active_matter
require game.es.zone_weather_common


[es(tag=server, REQUIRE=zone_weather__state)]
def zone_weather_moving_zone_started(evt : EventOnMovingZoneStarted;
                                     eid : EntityId;
                                     zone_weather__zoneRadiusAvgAtFinalStage : float = 20.0;
                                     zone_weather__manualActivation : bool = false)
  if zone_weather__manualActivation
    return

  let zoneFound = find_query() <| $ [es] (moving_zone__movingVelocity : float;
                                          moving_zone__sourceRadius : float)
    let riseTime = safediv(moving_zone__sourceRadius - zone_weather__zoneRadiusAvgAtFinalStage, moving_zone__movingVelocity)
    send_net_event(eid, CmdZoneWeatherStartStorm(riseTime = riseTime))

    return true

  if !zoneFound
    logerr("[ZONE WEATHER] Moving zone is not found!")


[es]
def zone_weather_start_storm(evt : CmdZoneWeatherStartStorm;
                             var zone_weather__state : int&;
                             var zone_weather__riseTime : float&)
  zone_weather__riseTime = evt.riseTime
  zone_weather__state = int(ZoneWeatherState.STORM)


[es]
def zone_weather_stop_storm(evt : CmdZoneWeatherStopStorm;
                            var zone_weather__state : int&;
                            var zone_weather__recoveryTime : float&)
  zone_weather__recoveryTime = evt.recoveryTime
  zone_weather__state = int(ZoneWeatherState.DEFAULT)