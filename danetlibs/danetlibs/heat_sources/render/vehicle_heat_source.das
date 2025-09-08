require ecs
require ecs.common
require math
require math.base
require DagorSystem
require DagorMath
require AnimV20
require GeomNodeTree
require strings
require dm
require DngDm
require CollRes
require vehicle
require danetlibs.heat_sources.render.heat_source_common

[es(tag=render, REQUIRE=vehicle, after=technic_heat_source_init_es, before=update_heat_sources_pos_es)]
def vehicle_heat_source_update_es(info : ParallelUpdateFrameDelayed;
                                  transform : float3x4;
                                  collres : CollisionResource;
                                  animchar : AnimcharBaseComponent;
                                  damage_model : DamageModel;
                                  heat_source__dmEnginePartIds : IntList;
                                  heat_source__dmRadiatorPartIds : IntList;
                                  dm_phys_parts__tracksPartIds : IntList;
                                  heat_source__dmWheelsPartIds : IntList;
                                  heat_source__hullEid : EntityId;
                                  heat_source__enginesEids : EidList;
                                  heat_source__radiatorsEids : EidList;
                                  heat_source__tracksEids : EidList;
                                  heat_source__wheelsEids : EidList)
  //hull
  var tm : float3x4
  tm = transform
  query(heat_source__hullEid) <| $ [es] (var transform : float3x4&)
    transform = tm

  //engine
  for partId, heatEid in heat_source__dmEnginePartIds, heat_source__enginesEids
    let collisionNodeId = get_collision_node_id(damage_model.dmData, partId)
    updateHeatSourceTm(transform, collres, animchar, collisionNodeId, heatEid)

  //radiator
  for partId, heatEid in heat_source__dmRadiatorPartIds, heat_source__radiatorsEids
    let collisionNodeId = get_collision_node_id(damage_model.dmData, partId)
    updateHeatSourceTm(transform, collres, animchar, collisionNodeId, heatEid)

  //tracks
  for partId, heatEid in dm_phys_parts__tracksPartIds, heat_source__tracksEids
    let collisionNodeId = get_collision_node_id(damage_model.dmData, partId)
    updateHeatSourceTm(transform, collres, animchar, collisionNodeId, heatEid)

  //wheels
  for partId, heatEid in heat_source__dmWheelsPartIds, heat_source__wheelsEids
    let collisionNodeId = get_collision_node_id(damage_model.dmData, partId)
    updateHeatSourceTm(transform, collres, animchar, collisionNodeId, heatEid)

def is_engine_broken(vehicle_net_phys : VehiclePhysActor)
  return vehicle_net_phys.phys.engineReadyness <= 0.0

def get_speed(vehicle_net_phys : VehiclePhysActor) : array<float>
  var result : array<float>
  let leftTrackSpeed = vehicle_net_phys.phys.currentState.leftTrack.speed
  let rightTrackSpeed = vehicle_net_phys.phys.currentState.rightTrack.speed
  result |> push() <| leftTrackSpeed
  result |> push() <| rightTrackSpeed
  return <- result

[es(tag=render, before=vehicle_heat_source_update_es)]
def vehicle_temperature_update_es(info : ParallelUpdateFrameDelayed;
                                  vehicle_net_phys : VehiclePhysActor;
                                  isAlive : bool;
                                  isExploded : bool;
                                  fatal_explosion_fire__endTime : float;
                                  heat_source__hullEid : EntityId;
                                  heat_source__enginesEids : EidList;
                                  heat_source__radiatorsEids : EidList;
                                  heat_source__tracksEids : EidList;
                                  heat_source__wheelsEids : EidList;
                                  heat_source__dead_technic_temp_mult : float;
                                  heat_source__engine_temp_mult : float;
                                  heat_source__radiator_temp_mult : float;
                                  heat_source__track_temp_max : float2;
                                  heat_source__wheel_temp_max : float2;
                                  heat_source__engine_temp_max : float;
                                  heat_source__engine_heating_spd : float2;
                                  heat_source__track_heating_spd : float2;
                                  heat_source__wheel_heating_spd : float2;
                                  heat_source__hull_base_temp : float;
                                  heat_source__hull_cooling_speed : float;
                                  heat_source__on_fire_technic_temp_mult : float)
  //hull
  if isExploded
    query(heat_source__hullEid) <| $ [es] (var heat_source__temperature : float4&)
      if info.curTime >= fatal_explosion_fire__endTime && fatal_explosion_fire__endTime > 0.f
        let resultHullTemp = clamp(heat_source__temperature.y - heat_source__hull_cooling_speed * info.dt, 0.0f, heat_source__on_fire_technic_temp_mult * heat_source__hull_base_temp)
        heat_source__temperature = float4(1.0f, resultHullTemp, 1.0f, resultHullTemp)
    return
  let multHull = isAlive ? 1.f : heat_source__dead_technic_temp_mult
  //engines
  let enigneRPM = vehicle_net_phys.phys.engineRPM
  let rpm = isAlive ? abs(enigneRPM) : 0.0f
  let heatingSpd = (rpm < FLT_EPSILON) ? heat_source__engine_heating_spd.y : heat_source__engine_heating_spd.x
  var currentEngineTemp = float4(0, 0, 0, 0)
  let mult = is_engine_broken(vehicle_net_phys) ? 0.0 : 1.0
  for eid in heat_source__enginesEids
    query(eid) <| $ [es] (var heat_source__temperature : float4&)
      heat_source__temperature.w = clamp(heat_source__temperature.w + heatingSpd * info.dt, 0.f, heat_source__engine_temp_max) * mult
      heat_source__temperature.y = heat_source__engine_temp_mult * (heat_source__engine_temp_max) * safediv(heat_source__temperature.w, heat_source__engine_temp_max) * mult
      currentEngineTemp = heat_source__temperature

  //radiators
  for eid in heat_source__radiatorsEids
    query(eid) <| $ [es] (var heat_source__temperature : float4&)
      heat_source__temperature = float4(currentEngineTemp.x, currentEngineTemp.y * heat_source__radiator_temp_mult,
        currentEngineTemp.z, currentEngineTemp.w)
  //tracks
  let trackSpeed <- get_speed(vehicle_net_phys)
  for eid, speed in heat_source__tracksEids, trackSpeed
    query(eid) <| $ [es] (var heat_source__temperature : float4&)
      heat_source__temperature.w += ((heat_source__temperature.w > heat_source__track_temp_max.x *
        safediv(abs(speed), heat_source__track_temp_max.y / 3.6)) ?
        heat_source__track_heating_spd.y : heat_source__track_heating_spd.x) * info.dt
      heat_source__temperature.w *= multHull
      heat_source__temperature.y = clamp(heat_source__temperature.y, 0.2f, 300.f)
      heat_source__temperature.w = clamp(heat_source__temperature.w, 0.2f, 300.f)

  //wheels
  let wheelSpeed = trackSpeed[0]
  for eid in heat_source__wheelsEids
    query(eid) <| $ [es] (var heat_source__temperature : float4&)
      heat_source__temperature.y += ((heat_source__temperature.y > heat_source__wheel_temp_max.x *
        safediv(abs(wheelSpeed), heat_source__wheel_temp_max.y / 3.6)) ?
        heat_source__wheel_heating_spd.y : heat_source__wheel_heating_spd.x) * info.dt
      heat_source__temperature.x = 7.0
      heat_source__temperature.y = clamp(heat_source__temperature.y, 0.2f, 300.f)
      heat_source__temperature.z = 7.0
      heat_source__temperature.w = clamp(heat_source__temperature.w, 0.2f, 300.f)
