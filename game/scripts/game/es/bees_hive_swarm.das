require ecs
require ecs.safe
require ecs.common
require math.base
require DagorRandom
require math.random
require game.es.riextra_damage_common
require game.events.events_active_matter
require DagorSystem


[es(tag=server, on_event=EventLevelLoaded)]
def hive_clusters_manager_level_loaded(evt : Event;
                                       hivesToSpawnRng : int2)
  var possibleHivePlaces : array<EntityId>
  query() <| $ [es(REQUIRE=hive_point__avaliableHivePresets)] (eid : EntityId)
    possibleHivePlaces |> push(eid)

  if !empty(possibleHivePlaces)
    possibleHivePlaces |> shuffle()
    let hivesToSpawn = rnd_int(hivesToSpawnRng)
    for placeIdx in range(min(hivesToSpawn, length(possibleHivePlaces)))
      query(possibleHivePlaces[placeIdx]) <| $ [es] (hive_point__avaliableHivePresets : StringList;
                                                     hive_point__avaliableBeesPresets : StringList;
                                                     transform : float3x4)
        let hivePresetIdx = rnd_int(0, length(hive_point__avaliableHivePresets) - 1)
        let hivePresetEid = createEntity("{hive_point__avaliableHivePresets[hivePresetIdx]}") <| $(var init)
          init |> set("transform", transform)
        let beesPresetIdx = rnd_int(0, length(hive_point__avaliableBeesPresets) - 1)
        createEntity("{hive_point__avaliableBeesPresets[beesPresetIdx]}") <| $(var init)
          init |> set("hive_point__transform", transform)
          init |> set("hive_point__hiveClusterEid", hivePresetEid)


[es(on_appear)]
def hive_cluster_on_create(evt : Event;
                           transform : float3x4;
                           var hive_cluster_preset__rendinsts : Array;
                           var hive_cluster_preset__rendinstsEids : EidList)
  for rendinst in hive_cluster_preset__rendinsts
    var rendinstObj = rendinst as Object
    let templ = get_string(rendinstObj, "template", "")
    if templ == ""
      continue
    let tm = get_TMatrix(rendinstObj, "tm") ?? IDENT_TM
    let rendinstEid = createEntity(templ) <| $(var init)
      init |> set("transform", transform * tm)
    hive_cluster_preset__rendinstsEids |> push(rendinstEid)


[es(on_appear)]
def bees_preset_on_create(evt : Event;
                          eid : EntityId;
                          hive_point__transform : float3x4;
                          bees_swarm_preset__templateName : string;
                          bees_swarm_preset__swarmCount : int;
                          am_habitat_swarm__maxFlightDistance : float;
                          swarm_cluster__hivePlace : float3x4;
                          hive_point__hiveClusterEid : EntityId)
  let hiveTm = hive_point__transform * swarm_cluster__hivePlace
  let startAngleStep = TWOPI / float(bees_swarm_preset__swarmCount)

  var transform = hiveTm
  var curStartAngle = 0.0
  for _ in range(bees_swarm_preset__swarmCount)
    let dir = float3(cos(curStartAngle), 0.0, sin(curStartAngle))
    transform[3] = hiveTm[3] + dir * am_habitat_swarm__maxFlightDistance
    createEntity(bees_swarm_preset__templateName) <| $(var init : ComponentsInitializer)
      init |> set("transform", transform)
      init |> set("swarm__orbitAngle", curStartAngle)
      init |> set("swarm_cluster__hivePos", hiveTm[3])
      init |> set("swarm_cluster__hiveClusterEid", hive_point__hiveClusterEid)
      curStartAngle += startAngleStep
  destroyEntity(eid)


// to place a cluster on the map
[es(on_event=CmdTeleportEntity)]
def on_cluster_position_changed(evt : Event;
                                transform aka cluster_transform : float3x4;
                                hive_cluster_preset__rendinsts : Array;
                                hive_cluster_preset__rendinstsEids : EidList)
  if length(hive_cluster_preset__rendinsts) != length(hive_cluster_preset__rendinstsEids)
    logerr("[Hive Cluster Position Changed] Length of hive_cluster_preset__rendinsts is not equal to length of hive_cluster_preset__rendinstsEids, cannot replace hive cluster")
    return
  for i in range(length(hive_cluster_preset__rendinsts))
    let rendinstObj = hive_cluster_preset__rendinsts[i] as Object
    let tm = get_TMatrix(rendinstObj, "tm") ?? IDENT_TM
    query(hive_cluster_preset__rendinstsEids[i]) <| $ [es] (var transform aka hive_transform : float3x4)
      hive_transform = cluster_transform * tm


[es(on_disappear)]
def hive_cluster_on_destroy(evt : Event;
                            hive_cluster_preset__rendinstsEids : EidList)
  for eid in hive_cluster_preset__rendinstsEids
    destroyEntity(eid)


[es(tag=server)]
def recalculate_swarm_cluster_spawn_mult_on_hive_destruction(evt : EventBeehiveDestruction;
                                                             swarm_cluster__hiveClusterEid : EntityId;
                                                             var swarm_cluster__spawnMult : float&)
  query(swarm_cluster__hiveClusterEid) <| $ [es] (hive_cluster_preset__rendinstsEids : EidList)
    if hive_cluster_preset__rendinstsEids |> find_index(evt.beehiveEid) >= 0
      let hivesCount = length(hive_cluster_preset__rendinstsEids)
      if hivesCount == 0
        return

      let aliveHives = calculate_ri_alive_count(hive_cluster_preset__rendinstsEids)

      swarm_cluster__spawnMult = float(aliveHives) / float(hivesCount)