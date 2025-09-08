require app
require ecs
require math.base
require ecs.common
require DagorMath
require game.es.level_common

[es(tag=server, on_appear)]
def indoor_patroller_setup(evt : Event; eid : EntityId; indoor_patroller__indoorCheckDelta : float;
                           var indoor_patroller__indoorCheckAt : float&)
  indoor_patroller__indoorCheckAt = get_sync_time() + indoor_patroller__indoorCheckDelta * eid_frnd(eid)

[es(tag=server, no_order)]
def indoor_patroller_update(act : UpdateStageInfoAct; transform : float3x4;
                            indoor_patroller__indoorCheckDelta : float;
                            var indoor_patroller__lastIndoorTime : float&;
                            var indoor_patroller__lastIndoorPos : float3&;
                            var indoor_patroller__indoorCheckAt : float&)
  if act.curTime < indoor_patroller__indoorCheckAt
    return

  indoor_patroller__indoorCheckAt = act.curTime + indoor_patroller__indoorCheckDelta

  let curPos = transform[3]
  if level_common::is_pos_indoor(curPos)
    indoor_patroller__lastIndoorPos = curPos
    indoor_patroller__lastIndoorTime = act.curTime

[es(tag=server, no_order)]
def indoor_patroller_outside_update(act : UpdateStageInfoAct; transform : float3x4;
                                    indoor_patroller__lastIndoorTime, indoor_patroller__indoorCheckAt : float;
                                    indoor_patroller__lastIndoorPos : float3;
                                    indoor_patroller__indoorCheckDelta : float;
                                    indoor_patroller__maxLeashDist : float;
                                    var entity_mods__visualAttractMaxDistMultMods : Object;
                                    var entity_mods__attractPointSearchRadiusMultMods : Object)
  if indoor_patroller__lastIndoorTime + indoor_patroller__indoorCheckDelta >= indoor_patroller__indoorCheckAt
    entity_mods__visualAttractMaxDistMultMods |> erase("outdoor")
    entity_mods__attractPointSearchRadiusMultMods |> erase("outdoor")
    return

  let dist = distance(transform[3], indoor_patroller__lastIndoorPos)
  let scale = 1f - saturate(safediv(dist, indoor_patroller__maxLeashDist))
  entity_mods__visualAttractMaxDistMultMods |> set("outdoor", scale)
  entity_mods__attractPointSearchRadiusMultMods |> set("outdoor", scale)
