require ecs
require ecs.common
require DngNet
require vehicle
require math
require math.base
require dm
require Dacoll
require game.events.vehicle_events
require game.events.events_active_matter
require game.es.vehicle.vehicle_seats_common

[es(tag=server, no_order)]
def vehicle_underwater_es(info : ParallelUpdateFrameDelayed;
                          transform : float3x4;
                          eid : EntityId;
                          fire_damage__isBurn : bool;
                          drowningHeight : float;
                          var damage_model : DamageModel&;
                          dm_phys_parts__enginePartIds : IntList;
                          underWaterMaxTime : float;
                          var underWaterStartTime : float&;
                          last_driver_leave_time : float)
  var isUnderWater : bool = true
  var hasAliveEngines : bool = true
  let pos : float3 = transform[3] + normalize(transform[1]) * drowningHeight
  let distToLand : float = 5.
  if !is_valid_water_height(traceht_water_at_time(pos, distToLand, info.curTime, isUnderWater))
    return

  if fire_damage__isBurn && isUnderWater
    sendEvent(eid, CmdStopBurn())
    sendEvent(eid, CmdRestore())

  for partId in dm_phys_parts__enginePartIds
    if int(get_rel_hp_fixed(damage_model.dmData, partId)) == 0
      hasAliveEngines = false
      break
  let lastDriverTime : float = get_vehicle_driver(eid) != INVALID_ENTITY_ID ? info.curTime : last_driver_leave_time
  if lastDriverTime + underWaterMaxTime * 2.f < info.curTime || !isUnderWater || !hasAliveEngines
    underWaterStartTime = -1.f
    return
  if underWaterStartTime < 0.f
    underWaterStartTime = info.curTime
    return
  if info.curTime - underWaterStartTime > underWaterMaxTime
    for partId in dm_phys_parts__enginePartIds
      if int(get_rel_hp_fixed(damage_model.dmData, partId)) != 0
        deal_damage_to_part(damage_model, eid, partId, 0, 0, get_max_hp(damage_model.dmData, partId), HitData())
        underWaterStartTime = 0.0
