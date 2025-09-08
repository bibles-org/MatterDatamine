require ecs
require math.base
require DagorMath
require DagorRandom


[es(tag=render, no_order)]
def metal_heat_effect_appear(act : UpdateStageInfoAct; eid : EntityId;
                             anomaly_effect__ownerAnomalyEid : EntityId;
                             metal_heat__hazeEffectTemplate : string;
                             metal_heat__hazeEffectsMaxCount : int;
                             metal_heat__hazeEffectsWidth = 0.3;
                             metal_heat__hazeEffectsSpawnInterval = 0.4;
                             var metal_heat__hazeEffectsSpawnAt : float&)
  if act.curTime < metal_heat__hazeEffectsSpawnAt
    return
  var count = 0
  find_query() <| $ [es(REQUIRE=metal_heat__hazeEffect)] (game_effect__attachedTo : EntityId)
    if game_effect__attachedTo == eid
      count ++
      if count >= metal_heat__hazeEffectsMaxCount
        return true
    return false
  if count >= metal_heat__hazeEffectsMaxCount
    return

  query(anomaly_effect__ownerAnomalyEid) <| $ [es] (indoor_spawner__inflatedBox : float3; transform : float3x4)
    var tm = transform
    orthonormalize(tm)
    let xWidth = 0.5 * max(0., length(transform[0]) - indoor_spawner__inflatedBox.x - metal_heat__hazeEffectsWidth)
    let yWidth = 0.5 * max(0., length(transform[1]) - indoor_spawner__inflatedBox.y - metal_heat__hazeEffectsWidth)
    let zWidth = 0.5 * max(0., length(transform[2]) - indoor_spawner__inflatedBox.z - metal_heat__hazeEffectsWidth)
    let offset = float3(rnd_float(-xWidth, xWidth), rnd_float(-yWidth, yWidth), rnd_float(-zWidth, zWidth))
    tm[3] += rotate(tm, offset)
    createEntity(metal_heat__hazeEffectTemplate) <| $(init)
      init |> set("transform", tm)
      init |> set("game_effect__attachedTo", eid)
    metal_heat__hazeEffectsSpawnAt = act.curTime + metal_heat__hazeEffectsSpawnInterval


[es(tag=render, on_disappear)]
def metal_heat_effect_disappear(evt : Event; eid aka heat_eid : EntityId)
  query() <| $ [es(REQUIRE=metal_heat__hazeEffect)] (eid, game_effect__attachedTo : EntityId)
    if game_effect__attachedTo == heat_eid
      destroyEntity(eid)


[es(tag=render, no_order)]
def move_metal_heat_light(act : UpdateStageInfoAct;
                          metal_heat_light__movePosMaxOffset, metal_heat_light__movePosSpeed : float3;
                          var transform : float3x4&;
                          var metal_heat_light__movePosOffset : float3&)
  transform[3] -= metal_heat_light__movePosOffset
  metal_heat_light__movePosOffset.x = sin(act.curTime * metal_heat_light__movePosSpeed.x) * metal_heat_light__movePosMaxOffset.x
  metal_heat_light__movePosOffset.y = sin(act.curTime * metal_heat_light__movePosSpeed.y) * metal_heat_light__movePosMaxOffset.y
  metal_heat_light__movePosOffset.z = sin(act.curTime * metal_heat_light__movePosSpeed.z) * metal_heat_light__movePosMaxOffset.z
  transform[3] += metal_heat_light__movePosOffset
