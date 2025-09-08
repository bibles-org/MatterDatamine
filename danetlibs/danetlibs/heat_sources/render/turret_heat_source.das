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
require Plane
require DngPlane
require danetlibs.heat_sources.render.heat_source_common

[es(tag=render, on_appear, REQUIRE=resolvedTurret, REQUIRE_NOT=gun__isLauncher, after=technic_heat_source_init_es)]
def turret_heat_source_init_es(evt : Event;
                               eid : EntityId;
                               turret_dm_part__barrelDm : int;
                               turret__owner : EntityId;
                               turret__name : string;
                               turret__aimNodeId : int)
  if turret_dm_part__barrelDm < 0
    return
  var thermalRendererEid = INVALID_ENTITY_ID
  query() <| $ [es(REQUIRE=thermal_vision__activePresetEid)] (eid : EntityId)
    thermalRendererEid = eid
  let turretEid = eid
  query(turret__owner) <| $ [es] (var heat_source__gunsEntityEid : EidList&;
                                  var heat_source__gunsEids : EidList&;
                                  var heat_source__dmGunPartIds : IntList&;
                                  heat_source__turret_main_gun_size : float3;
                                  heat_source__turret_main_gun_offset : float3;
                                  heat_source__turret_main_gun_rad_offset_mult : float;
                                  heat_source__turret_mg_gun_size : float3;
                                  heat_source__turret_mg_gun_offset : float3;
                                  heat_source__turret_mg_gun_rad_offset_mult : float;
                                  @shared_comp heat_source__turretInfo : Array const?;
                                  transform : float3x4;
                                  collres : CollisionResource;
                                  animchar : AnimcharBaseComponent;
                                  damage_model : DamageModel)
    let gunTemperature = float4(7, 0, 0, 0)
    var gunType = partType.TANK_GUN_MAIN
    var scale = heat_source__turret_main_gun_size
    var offset = heat_source__turret_main_gun_offset
    var radMult = heat_source__turret_main_gun_rad_offset_mult
    var isOverheat = false
    if has(turretEid, "gun__isOverheat")
      gunType = partType.TANK_GUN_MAIN_OVERHEATED
      isOverheat = true
      if !has(turretEid, "mainTurret") && turret__aimNodeId >= 0 // heuristic -- turrets that do not have turret__aimNodeId (nodeId < 0) and don't have tag "mainTurret" are actually coaxial machineguns
        gunType = partType.TANK_MG
        scale = heat_source__turret_mg_gun_size
        offset = heat_source__turret_mg_gun_offset
        radMult = heat_source__turret_mg_gun_rad_offset_mult
    if heat_source__turretInfo != null
      find_turret_heat_source_params((*heat_source__turretInfo), turret__name,
        offset, scale, radMult)
    if gunType == partType.TANK_GUN_MAIN && thermalRendererEid == INVALID_ENTITY_ID
      return // in case when we don't have thermal render entity on map we don't spawn heatsource for main gun
    heat_source__gunsEntityEid |> push(turretEid)
    createHeatSource(transform, collres, animchar, damage_model,
      turret_dm_part__barrelDm,
      heat_source__gunsEids,
      gunTemperature,
      offset,
      scale,
      gunType,
      isOverheat,
      true,
      float3(-1, 0, 0),
      radMult)
    heat_source__dmGunPartIds |> push(turret_dm_part__barrelDm)


[es(tag=render, after=turret_heat_source_init_es, before=update_heat_sources_pos_es)]
def turret_heat_source_update_es(info : ParallelUpdateFrameDelayed;
                                 transform : float3x4;
                                 collres : CollisionResource;
                                 animchar : AnimcharBaseComponent;
                                 damage_model : DamageModel;
                                 heat_source__dmGunPartIds : IntList&;
                                 heat_source__gunsEids : EidList)
  for partId, heatEid in heat_source__dmGunPartIds, heat_source__gunsEids
    let collisionNodeId = get_collision_node_id(damage_model.dmData, partId)
    updateHeatSourceTm(transform, collres, animchar, collisionNodeId, heatEid)

[es(tag=render, before=turret_heat_source_update_es)]
def turret_temperature_update_es(info : ParallelUpdateFrameDelayed;
                                 heat_source__gunsEids : EidList;
                                 heat_source__gunsEntityEid : EidList;
                                 heat_source__gun_base_temp : float3)

  var overheatGunCoeff = 0.125f
  query() <| $ [es] (heat_source__overheatGunCoeff : float)
    overheatGunCoeff = heat_source__overheatGunCoeff

  for heatEid, gunEid in heat_source__gunsEids, heat_source__gunsEntityEid
    query(heatEid) <| $ [es] (var heat_source__temperature : float4&;
                              heat_source__type : int)
      var gunTemp = 0.0
      if (heat_source__type == int(partType.TANK_GUN_MAIN))
        gunTemp = max(0.f, heat_source__temperature.y + heat_source__gun_base_temp.z * info.dt)
      else
        query(gunEid) <| $ [es] (var gun__overheatVisual : float&;
                                 gun__overheatReduceOnOverheat : float;
                                 gun__overheatReduce : float;
                                 gun__isOverheat : bool&)
          //some turrets have value of gun__overheatReduce = 0.0 (for example flamethrowers),
          //so when gun__overheatReduce will be 0.0 we will use gun__overheatReduceOnOverheat, to avoid bug with always red barrels
          let overheatReduce = !gun__isOverheat && gun__overheatReduce > 0.0 ? gun__overheatReduce : gun__overheatReduceOnOverheat
          gun__overheatVisual = max(gun__overheatVisual - overheatReduce * info.dt, 0.f)
          gunTemp = gun__overheatVisual * (heat_source__gun_base_temp.x * overheatGunCoeff)
      heat_source__temperature.y = gunTemp

[es(tag=render, on_event=(CmdNetShot, EventShot))]
def gun_set_temp_on_shot(evt : Event;
                         eid : EntityId;
                         turret__owner : EntityId)

  var overheatGunCoeff = 0.125f
  query() <| $ [es] (heat_source__overheatGunCoeff : float)
    overheatGunCoeff = heat_source__overheatGunCoeff

  var heatEid : EntityId = INVALID_ENTITY_ID
  var barrelTemperature : float3
  let gunEid = eid
  query(turret__owner) <| $ [es] (heat_source__gunsEids : EidList;
                                  heat_source__gunsEntityEid : EidList;
                                  heat_source__gun_base_temp : float3&)
    barrelTemperature = heat_source__gun_base_temp
    for turretId, heatId in heat_source__gunsEntityEid, heat_source__gunsEids
      if (turretId == gunEid)
        heatEid = heatId
  query(heatEid) <| $ [es] (var heat_source__temperature : float4&;
                            heat_source__type : int)
    var gunTemp = 0.0
    if (heat_source__type == int(partType.TANK_GUN_MAIN))
      gunTemp = min(barrelTemperature.x, heat_source__temperature.y + barrelTemperature.y)
    else
      query(gunEid) <| $ [es] (gun__overheatPerShot : float;
                               gun__isOverheat : bool&;
                               var gun__overheatVisual : float&)
        if !gun__isOverheat
          gun__overheatVisual = min(gun__overheatVisual + gun__overheatPerShot, 1.f)
        gunTemp = gun__overheatVisual * (barrelTemperature.x * overheatGunCoeff)
    heat_source__temperature.y = gunTemp

[es(tag=render, on_disappear)]
def turret_heat_source_destroy_es(evt : Event;
                                  var heat_source__gunsEids : EidList)
  destroyHeatSources(heat_source__gunsEids)

[es(tag=render, track=isExploded)]
def fatal_explosion_turret_heat_source_es(evt : Event;
                                          isExploded : bool;
                                          var heat_source__gunsEids : EidList)
  if isExploded
    destroyHeatSources(heat_source__gunsEids)
