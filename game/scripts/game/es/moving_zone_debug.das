options no_aot
require app
require ecs
require DagorConsole

[console_cmd(name="moving_zone.set_radius")]
def set_moving_zone_radius(value : float)
  find_query() <| $ [es] (var moving_zone__sourceRadius, moving_zone__targetRadius : float&)
    moving_zone__sourceRadius = value
    moving_zone__targetRadius = value
    return true


[console_cmd(name="moving_zone.start_moving")]
def moving_zone_start_moving(value : float = 1.f)
  find_query() <| $ [es] (active : bool;
                          var moving_zone__startEndTime : float2&;
                          var moving_zone__manual_activation : bool&)
    if active
      return true
    moving_zone__startEndTime.x = get_sync_time() + value
    moving_zone__manual_activation = false
    return true
