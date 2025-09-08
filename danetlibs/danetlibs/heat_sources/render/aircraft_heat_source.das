require ecs
require ecs.common
require ecs.safe
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
require RegExp
require danetlibs.heat_sources.render.heat_source_common

[es(tag=render, on_appear, REQUIRE=airplane, after=technic_heat_source_init_es, before=update_heat_sources_pos_es)]
def aircraft_additional_heat_source_init_es(evt : Event;
                                            animchar : AnimcharBaseComponent;
                                            transform : float3x4;
                                            collres : CollisionResource;
                                            damage_model : DamageModel;
                                            heat_source_jetFlamePatterns : Array;
                                            heat_source__jet_flame_offset : float3;
                                            heat_source__jet_flame_size : float3;
                                            heat_source__dmEnginePartIds : IntList;
                                            var heat_source__jetFlameNodeId : IntList;
                                            var heat_source__jetFlameEid : EidList)
  for pattern in heat_source_jetFlamePatterns
    let patternString = "{get_ecs_string(pattern)}"
    using() <| $(var regexTester : RegExp)
      regexTester |> compile(patternString, "", 0)
      let nodesCount = int(animchar.nodeTree.nodeCount)
      for i in range(0, nodesCount)
        let nodeName = geomtree_getNodeName(*animchar.nodeTree, i)
        if (regexTester |> test(nodeName, 0)) != 0
          push(heat_source__jetFlameNodeId, i)

  for nodeId, partId in heat_source__jetFlameNodeId, heat_source__dmEnginePartIds
    let collisionNodeId = get_collision_node_id(damage_model.dmData, partId)
    let node = collres_get_node(collres, collisionNodeId)
    if node != null
      var tm : float3x4
      collres_get_collision_node_tm(collres, collisionNodeId, transform, animchar.nodeTree, tm)
      let partModelBBox = (*node).modelBBox
      var rad : float3
      rad = partModelBBox.width
      let partTemperature =  float4(2.0f, 0.0f, 1.0f, 0.0f)
      let pos = geomtree_getNodeWpos(*animchar.nodeTree, nodeId)
      tm[3] = pos
      let heatEid = createEntity("heat_source_item") <| $(var init : ComponentsInitializer)
        set(init, "transform", tm)
        set(init, "heat_source__basicRad", rad)
        set(init, "heat_source__basicScale", heat_source__jet_flame_size)
        set(init, "heat_source__scale", heat_source__jet_flame_size)
        set(init, "heat_source__dirRadOffset", float3(0, 1, 0))
        set(init, "heat_source__radMult", 1.0f)
        set(init, "heat_source__offset", heat_source__jet_flame_offset)
        set(init, "heat_source__temperature", partTemperature)
        set(init, "heat_source__needUpdate", true)
        set(init, "heat_source__type", int(partType.ENGINE))
      push(heat_source__jetFlameEid, heatEid)

[es(tag=render, REQUIRE=airplane, after=technic_heat_source_init_es, before=update_heat_sources_pos_es)]
def aircraft_heat_source_update_es(info : ParallelUpdateFrameDelayed;
                                   transform aka aircraft_transform : float3x4;
                                   collres : CollisionResource;
                                   animchar : AnimcharBaseComponent;
                                   damage_model : DamageModel;
                                   heat_source__dmEnginePartIds : IntList;
                                   heat_source__hullEid : EntityId;
                                   heat_source__enginesEids : EidList;
                                   heat_source__jetFlameNodeId : IntList;
                                   heat_source__jetFlameEid : EidList)
  //hull
  query(heat_source__hullEid) <| $ [es] (var transform : float3x4&)
    transform = aircraft_transform

  //engine
  for partId, heatEid in heat_source__dmEnginePartIds, heat_source__enginesEids
    let collisionNodeId = get_collision_node_id(damage_model.dmData, partId)
    updateHeatSourceTm(transform, collres, animchar, collisionNodeId, heatEid)

  for nodeId, heatEid, partId in heat_source__jetFlameNodeId, heat_source__jetFlameEid, heat_source__dmEnginePartIds
    if heatEid == INVALID_ENTITY_ID
      return
    let collisionNodeId = get_collision_node_id(damage_model.dmData, partId)
    let node = collres_get_node(collres, collisionNodeId)
    if node != null
      var tm : float3x4
      collres_get_collision_node_tm(collres, collisionNodeId, aircraft_transform, animchar.nodeTree, tm)
      let pos = geomtree_getNodeWpos(*animchar.nodeTree, nodeId)
      tm[3] = pos
      query(heatEid) <| $ [es] (var transform : float3x4&)
        transform = tm

[es(tag=render, before=aircraft_heat_source_update_es)]
def aircraft_temperature_update_es(info : ParallelUpdateFrameDelayed;
                                   isExploded : bool;
                                   heat_source__hullEid : EntityId;
                                   heat_source__enginesEids : EidList;
                                   heat_source__jetFlameEid : EidList;
                                   heat_source__engine_temp_mult : float;
                                   heat_source__engine_temp_max : float;
                                   heat_source__engine_heating_spd : float2;
                                   heat_source__jet_flame_temp_mult : float;
                                   heat_source__hull_base_temp : float;
                                   heat_source__hull_cooling_speed : float;
                                   heat_source__on_fire_technic_temp_mult : float;
                                   contrail_fx__minThrottle : float;
                                   var plane_net_phys : PlaneActor&)
  //hull
  if isExploded
    query(heat_source__hullEid) <| $ [es] (var heat_source__temperature : float4&)
      let resultHullTemp = clamp(heat_source__temperature.y - heat_source__hull_cooling_speed * info.dt, 0.0f, heat_source__on_fire_technic_temp_mult * heat_source__hull_base_temp)
      heat_source__temperature = float4(1.0f, resultHullTemp, 1.0f, resultHullTemp)
    return
  //engines
  assume propulsion = plane_net_phys.phys.EI
  if propulsion != null
    let numEngines = (*propulsion).numEngines
    for eid, jetEid, i in heat_source__enginesEids, heat_source__jetFlameEid, range(numEngines)
      (*propulsion) |> propulsion_getEngine(i) <| $(engine)
        var mult = engine_hasFuel(engine, plane_net_phys.phys) || int(engine.stage) > int(EStage.E_STAGE_NOMINAL) || int(engine.damageLevel) >= MAX_ENGINE_DAMAGE_LEVEL ? 1.0f : 0.0f
        let heatingSpd = (engine.controlThrottle < contrail_fx__minThrottle) ? heat_source__engine_heating_spd.y : heat_source__engine_heating_spd.x
        mult *= engine.readyness
        var engineTemp = float4(2, 0, 1, 0)
        query(eid) <| $ [es] (var heat_source__temperature : float4&)
          heat_source__temperature.w = clamp(heat_source__temperature.w + heatingSpd * info.dt, 0.f, heat_source__engine_temp_max) * mult
          heat_source__temperature.y = heat_source__engine_temp_mult * (heat_source__engine_temp_max) * safediv(heat_source__temperature.w, heat_source__engine_temp_max) * mult
          engineTemp = heat_source__temperature
        query(jetEid) <| $ [es] (var heat_source__temperature : float4&)
          heat_source__temperature.w = engineTemp.w * heat_source__jet_flame_temp_mult
          heat_source__temperature.y = engineTemp.y * heat_source__jet_flame_temp_mult

[es(tag=render, on_disappear)]
def airacraft_additional_heat_source_destroy_es(evt : Event;
                                                var heat_source__jetFlameEid : EidList)
  destroyHeatSources(heat_source__jetFlameEid)
