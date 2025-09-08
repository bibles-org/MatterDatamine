require ecs
require game.events.events
require DagorRandom
require math.random
require Dacoll
require math.base
require game.es.inventory_item_common
require game.es.objectives.objective_common
require player


[es(tag=server, REQUIRE=groundGatherSamplesZoneTarget, on_event=EventLevelLoaded)]
def objective_gather_samples_create_ground_samples(evt : Event;
                                                   eid aka zone_eid : EntityId;
                                                   transform : float3x4;
                                                   quest_target_geometry_sphere__radius : float;
                                                   gather_samples_target__accesspointsCountRng : int2;
                                                   gather_samples_target__accesspointTemplate : string;
                                                   var gather_samples_target__accesspointEids : EidList&)

  let wishAccesspointCount = rnd_int(gather_samples_target__accesspointsCountRng.x, gather_samples_target__accesspointsCountRng.y)

  for _ in range(wishAccesspointCount)

    var tm = IDENT_TM
    let offset = rnd_point_on_disk(quest_target_geometry_sphere__radius)
    tm[3] += float3(offset.x, 5f, offset.y)
    tm = transform * tm

    var t = 10f
    var norm = float3()
    if traceray_normalized(tm[3], -tm[1], t, norm)
      tm[3] += -tm[1] * t

    let accesspointEid = createEntity(gather_samples_target__accesspointTemplate) <| $(init)
      set(init, "transform", tm)
      set(init, "external_inventory_accesspoint__inventoryEid", zone_eid)
    push(gather_samples_target__accesspointEids, accesspointEid)


[es(tag=server, REQUIRE=waterGatherSamplesZoneTarget, on_event=EventLevelLoaded)]
def objective_gather_samples_create_water_samples(evt : Event;
                                                  eid aka zone_eid : EntityId;
                                                  transform : float3x4;
                                                  quest_target_geometry_sphere__radius : float;
                                                  gather_samples_target__accesspointsCountRng : int2;
                                                  gather_samples_target__accesspointTemplate : string;
                                                  var gather_samples_target__accesspointEids : EidList&)

  let wishAccesspointCount = rnd_int(gather_samples_target__accesspointsCountRng.x, gather_samples_target__accesspointsCountRng.y)

  for _ in range(wishAccesspointCount)

    var tm = IDENT_TM
    let offset = rnd_point_on_disk(quest_target_geometry_sphere__radius)
    tm[3] += float3(offset.x, 0f, offset.y)
    tm = transform * tm

    var waterHeight = 0f
    if traceht_water(tm[3], waterHeight)
      tm[3].y = waterHeight

    let accesspointEid = createEntity(gather_samples_target__accesspointTemplate) <| $(init)
      set(init, "transform", tm)
      set(init, "external_inventory_accesspoint__inventoryEid", zone_eid)
    push(gather_samples_target__accesspointEids, accesspointEid)


// During handling the EventQuestStaticTargetAssigned event, the accesspoint may be in the loadingEntity state.
// Therefore, on on_appear we are trying to enable the ability to use a accesspoint
[es(tag=gameClient, on_appear, REQUIRE=getherSamplesContainerAccesspoint)]
def manage_use_gather_samples_accesspoint_on_appear(evt : Event;
                                                    external_inventory_accesspoint__inventoryEid : EntityId;
                                                    var use_object__enabled : bool&)
  var needEnable = false
  for_each_player_objective(get_local_player_eid()) <| $(objective_eid)
    query(objective_eid) <| $ [es(REQUIRE=objectiveGatherSamples)] (objective__staticTargetsList : EidList)
      needEnable ||= has_value(objective__staticTargetsList, external_inventory_accesspoint__inventoryEid)
  use_object__enabled = needEnable


[es(tag=gameClient)]
def enable_use_gather_samples_accesspoint_when_assigning(evt : EventQuestStaticTargetAssigned;
                                                         gather_samples_target__accesspointEids : EidList)
  if evt.playerEid != get_local_player_eid()
    return
  for accesspointEid in gather_samples_target__accesspointEids
    query(accesspointEid) <| $ [es(REQUIRE=getherSamplesContainerAccesspoint)] (var use_object__enabled : bool&)
      use_object__enabled = true