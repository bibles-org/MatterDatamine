require ecs
require DagorMath

[es(tag=server, on_appear)]
def init_zone_patroller(evt : Event; transform : float3x4; var zone_patroller__spawnPos : float3&)
  zone_patroller__spawnPos = transform[3]

[es(tag=server, no_order)]
def update_zone_patroller(act : UpdateStageInfoAct; transform : float3x4; zone_patroller__spawnPos : float3;
                          zone_patroller__maxLeashDist : float;
                          zone_patroller__aggroOnBorderMult : float;
                          zone_patroller__nextCheckDelta : float;
                          var zone_patroller__nextCheckAt : float&;
                          var zone_patroller__currentAggroMult : float&)
  if act.curTime < zone_patroller__nextCheckAt
    return
  zone_patroller__nextCheckAt = act.curTime + zone_patroller__nextCheckDelta

  let zoneTime = distance(transform[3], zone_patroller__spawnPos) / zone_patroller__maxLeashDist
  zone_patroller__currentAggroMult = cvt(zoneTime, 0f, 1f, 1f, zone_patroller__aggroOnBorderMult)
