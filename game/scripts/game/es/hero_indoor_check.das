require ecs
require game.events.events
require game.events.events_active_matter
require game.es.level_common
require DagorSystem
require DngNet

[es(tag=server, no_order)]
def hero_indoor_check(act : ParallelUpdateFrameDelayed;
                      var militant__indoorLastTime : float&;
                      var militant__indoor : bool&;
                      var militant__indoorCheckAt : float&;
                      militant__indoorStepCheckAt : float;
                      militant__alreadyOutside : float;
                      transform : float3x4)
  if act.curTime < militant__indoorCheckAt
    return
  militant__indoorCheckAt = act.curTime + militant__indoorStepCheckAt
  let position = transform[3]
  if level_common::is_pos_indoor(position)
    militant__indoorLastTime = act.curTime
    if !militant__indoor
      militant__indoor = true
  elif act.curTime - militant__indoorLastTime > militant__alreadyOutside && militant__indoor
    militant__indoor = false