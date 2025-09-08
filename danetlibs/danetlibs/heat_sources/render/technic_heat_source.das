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
require danetlibs.heat_sources.render.heat_source_common


[es(tag=render, on_appear, after=(dm_phys_parts_es, gather_technic_parts_es))]
def technic_heat_source_init_es(evt : Event;
                                transform : float3x4;
                                collres : CollisionResource;
                                animchar : AnimcharBaseComponent;
                                damage_model : DamageModel;
                                isAlive : bool;
                                heat_source__dmEnginePartIds : IntList;
                                heat_source__dmRadiatorPartIds : IntList;
                                dm_phys_parts__tracksPartIds : IntList const?;
                                heat_source__dmWheelsPartIds : IntList;
                                var heat_source__hullEid : EntityId&;
                                var heat_source__enginesEids : EidList&;
                                var heat_source__radiatorsEids : EidList&;
                                var heat_source__tracksEids : EidList&;
                                var heat_source__wheelsEids : EidList&;
                                heat_source__hull_offset : float3;
                                heat_source__hull_size : float3;
                                heat_source__engines_offset : float3;
                                heat_source__engines_size : float3;
                                heat_source__radiators_offset : float3;
                                heat_source__radiators_size : float3;
                                heat_source__tracks_offset : float3;
                                heat_source__tracks_size : float3;
                                heat_source__wheels_offset : float3;
                                heat_source__wheels_size : float3;
                                heat_source__hull_base_temp : float;
                                heat_source__hull_vertical_offset_coef : float)
  let mult = isAlive ? 1.0f : 0.0f
  //hull
  let hullTemp = heat_source__hull_base_temp
  let rad = collres.boundingBox.width
  let partTemperature = float4(1.0f, hullTemp * mult, 1.0f, hullTemp * mult)
  var tm : float3x4
  tm = transform
  heat_source__hullEid = createEntity("heat_source_item") <| $(var init : ComponentsInitializer)
    set(init, "transform", tm)
    set(init, "heat_source__basicRad", rad)
    set(init, "heat_source__basicScale", heat_source__hull_size)
    set(init, "heat_source__scale", heat_source__hull_size)
    set(init, "heat_source__dirRadOffset", float3(0, 1, 0))
    set(init, "heat_source__radMult", heat_source__hull_vertical_offset_coef)
    set(init, "heat_source__offset", heat_source__hull_offset)
    set(init, "heat_source__temperature", partTemperature)
    set(init, "heat_source__needUpdate", true)
    set(init, "heat_source__type", int(partType.HULL))

  //engine
  let engineTemperature = float4(2.0f, 0.0f, 1.0f, 0.0f)
  for partId in heat_source__dmEnginePartIds
    createHeatSource(transform, collres, animchar, damage_model, partId,
      heat_source__enginesEids,
      engineTemperature,
      heat_source__engines_offset,
      heat_source__engines_size,
      partType.ENGINE)

  //radiator
  let radiatorTemperature = float4(2.0f, 0.0f, 1.0f, 0.0f)
  for partId in heat_source__dmRadiatorPartIds
    createHeatSource(transform, collres, animchar, damage_model, partId,
      heat_source__radiatorsEids,
      radiatorTemperature,
      heat_source__radiators_offset,
      heat_source__radiators_size,
      partType.RADIATOR)

  //tracks
  if dm_phys_parts__tracksPartIds != null
    let trackTemperature = float4(0, 0, 7, 0)
    for partId in *dm_phys_parts__tracksPartIds
      createHeatSource(transform, collres, animchar, damage_model, partId,
        heat_source__tracksEids,
        trackTemperature,
        heat_source__tracks_offset,
        heat_source__tracks_size,
        partType.TRACK)

  //wheels
  let wheelTemperature = float4(-2.5, 0.0, 0.0, 0.0)
  for partId in heat_source__dmWheelsPartIds
    createHeatSource(transform, collres, animchar, damage_model, partId,
      heat_source__wheelsEids,
      wheelTemperature,
      heat_source__wheels_offset,
      heat_source__wheels_size,
      partType.WHEEL)

[es(tag=render, on_disappear)]
def technic_heat_source_destroy_es(evt : Event;
                                   heat_source__hullEid : EntityId;
                                   var heat_source__enginesEids : EidList;
                                   var heat_source__radiatorsEids : EidList;
                                   var heat_source__tracksEids : EidList;
                                   var heat_source__wheelsEids : EidList)
  destroyHeatSources(heat_source__enginesEids)
  destroyHeatSources(heat_source__radiatorsEids)
  destroyHeatSources(heat_source__tracksEids)
  destroyHeatSources(heat_source__wheelsEids)
  destroyEntity(heat_source__hullEid)


[es(tag=render, track=isExploded)]
def fatal_explosion_heat_source_es(evt : Event;
                                   isExploded : bool;
                                   heat_source__hullEid : EntityId;
                                   fatal_explosion_fire__ttl : float;
                                   heat_source__dead_technic_fadeout_coeff : float;
                                   heat_source__hull_base_temp : float;
                                   heat_source__on_fire_technic_temp_mult : float;
                                   var heat_source__enginesEids : EidList;
                                   var heat_source__radiatorsEids : EidList;
                                   var heat_source__tracksEids : EidList;
                                   var heat_source__wheelsEids : EidList)
  if isExploded
    destroyHeatSources(heat_source__enginesEids)
    destroyHeatSources(heat_source__radiatorsEids)
    destroyHeatSources(heat_source__tracksEids)
    destroyHeatSources(heat_source__wheelsEids)
    query(heat_source__hullEid) <| $ [es] (var heat_source__fadeout : bool&;
                                           var heat_source__fadeoutTime : float&;
                                           var heat_source__temperature : float4&)
      let temp = heat_source__hull_base_temp * heat_source__on_fire_technic_temp_mult
      heat_source__temperature = float4(1.0f, temp, 1.0f, temp)
      heat_source__fadeout = isExploded
      heat_source__fadeoutTime = fatal_explosion_fire__ttl * heat_source__dead_technic_fadeout_coeff
