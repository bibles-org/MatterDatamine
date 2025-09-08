require ecs
require ecs.common
require ecs.safe
require app
require math.base
require math.random
require ecs.soa_template
require pathfinder
require game.es.grav_zones_common
require game.es.ai.agent_position_mapping_common
require game.events.events_active_matter
require level
require Grid
require DagorMath
require DagorRandom
require DagorSystem
require game.es.extraction_point.extraction_point_common


[es(tag=server, on_appear)]
def extraction_point_defence_controller_appear(evt : Event;
                                               eid : EntityId;
                                               extraction_point_defence_controller__updateInterval : float;
                                               extraction_point_defence_controller__defendersCountInitial : int2;
                                               extraction_point_defence_controller__defendersSpawnBlockedInitial : float2;
                                               var extraction_point_defence_controller__defendersCountRequired : int&;
                                               var extraction_point_defence_controller__updateAt : float&;
                                               var extraction_point_defence_controller__defendersSpawnBlockedUntil : float&)
  extraction_point_defence_controller__defendersCountRequired = rnd_int(extraction_point_defence_controller__defendersCountInitial)
  extraction_point_defence_controller__updateAt = get_sync_time() + eid_frnd(eid) * extraction_point_defence_controller__updateInterval
  extraction_point_defence_controller__defendersSpawnBlockedUntil = get_sync_time() + rnd_float(extraction_point_defence_controller__defendersSpawnBlockedInitial)


def block_other_defence_controllers_spawn(current_defence_controller_eid : EntityId;
                                          current_defence_controller_transform : float3x4;
                                          radius : float;
                                          time : float2)
  let radiusSq = square(radius)

  query() <| $ [es] (eid aka extraction_eid : EntityId;
                     transform aka extraction_transform : float3x4;
                     var extraction_point_defence_controller__defendersSpawnBlockedUntil : float&)
    assume defendersSpawnBlockedUntil = extraction_point_defence_controller__defendersSpawnBlockedUntil

    if extraction_eid == current_defence_controller_eid
      return

    if distance_sq(current_defence_controller_transform[3], extraction_transform[3]) > radiusSq
      return

    defendersSpawnBlockedUntil = max(defendersSpawnBlockedUntil, get_sync_time() + rnd_float(time))


[es(tag=server, no_order)]
def extraction_point_defence_controller_update(act : UpdateStageInfoAct;
                                               eid aka extraction_eid : EntityId;
                                               transform aka extraction_transform : float3x4;
                                               extraction__currentState : int = int(ExtractionPointState.INACTIVE);
                                               extraction_point_defence_controller__enabled : bool;
                                               extraction_point_defence_controller__updateInterval : float;
                                               extraction_point_defence_controller__defendersSpawnRadius : float;
                                               extraction_point_defence_controller__defendersCountRequired : int;
                                               extraction_point_defence_controller__defenderTemplates : StringList;
                                               extraction_point_defence_controller__defenderKilledSpawnBlock : float2;
                                               extraction_point_defence_controller__defenderKilledOtherExtractionsSpawnBlock : float2 = float2(120, 180);
                                               extraction_point_defence_controller__defenderSpawnedSpawnBlock : float2;
                                               extraction_point_defence_controller__defenderVanishedSpawnBlock : float2;
                                               extraction_point_defence_controller__otherDefendersDetectRadius : float = 30.0;
                                               var extraction_point_defence_controller__defendersSpawnBlockedUntil : float&;
                                               var extraction_point_defence_controller__defendersList : EidList;
                                               var extraction_point_defence_controller__updateAt : float&)
  assume defendersSpawnBlockedUntil = extraction_point_defence_controller__defendersSpawnBlockedUntil
  assume defenderKilledSpawnBlock = extraction_point_defence_controller__defenderKilledSpawnBlock
  assume defenderSpawnedSpawnBlock = extraction_point_defence_controller__defenderSpawnedSpawnBlock
  assume defenderVanishedSpawnBlock = extraction_point_defence_controller__defenderVanishedSpawnBlock
  assume defendersCountRequired = extraction_point_defence_controller__defendersCountRequired
  assume defendersList = extraction_point_defence_controller__defendersList

  if !extraction_point_defence_controller__enabled
    return

  if act.curTime < extraction_point_defence_controller__updateAt
    return

  extraction_point_defence_controller__updateAt += extraction_point_defence_controller__updateInterval


  // Analyze valid defenders
  var defendersCount = length(defendersList)
  for defenderIdx in iter_range(defendersList)
    let reverseIdx = defendersCount - defenderIdx - 1
    let defenderEid = defendersList[reverseIdx]

    var isDefenderValid = false
    query(defenderEid) <| $ [es(REQUIRE_NOT=deadEntity)] ()
      isDefenderValid = true

    if !isDefenderValid && !isLoadingEntity(defenderEid)
      // Defender is dead
      defendersList |> erase(reverseIdx)
      defendersSpawnBlockedUntil = max(defendersSpawnBlockedUntil, get_sync_time()) + rnd_float(defenderKilledSpawnBlock)

      block_other_defence_controllers_spawn(extraction_eid, extraction_transform,
                                            extraction_point_defence_controller__otherDefendersDetectRadius,
                                            extraction_point_defence_controller__defenderKilledOtherExtractionsSpawnBlock)


  defendersCount = length(defendersList)

  // Spawn new defender
  if extraction_point_defence_controller__defendersSpawnBlockedUntil < act.curTime
    if (defendersCount < defendersCountRequired &&
      extraction__currentState != int(ExtractionPointState.DISABLED) &&
      is_level_loaded())

      // Calculate all defenders count around (including from other extraction points)
      var defendersAroundCount = 0
      let detectSphere = BSphere3(extraction_transform[3], extraction_point_defence_controller__otherDefendersDetectRadius)
      gather_entities_in_grid(ecs_hash("humans"), detectSphere, GridEntCheck.POS) <| $(humans_list)
        for humanEid in humans_list
          query(humanEid) <| $ [es(REQUIRE=invisible_man_extraction_point_defender)] ()
            defendersAroundCount++

      if defendersAroundCount < defendersCountRequired
        assume defenderTemplate = string(extraction_point_defence_controller__defenderTemplates[
          rnd_int(0, length(extraction_point_defence_controller__defenderTemplates) - 1)])

        let defenderEid = createEntity(defenderTemplate) <| $(var init : ComponentsInitializer)

          let spawnRadius = extraction_point_defence_controller__defendersSpawnRadius

          var tm = get_grav_tm(extraction_transform[3])
          let rndOffset = rnd_dir2() * rnd_float(0.0, spawnRadius)
          tm[3] += tm[0] * rndOffset.x + tm[2] * rndOffset.y
          project_to_nearest_navmesh_point_with_navmesh_mapping(tm[3], float3(10.0))

          set(init, "transform", tm)

        defendersList |> push(defenderEid)
        defendersSpawnBlockedUntil = max(defendersSpawnBlockedUntil, act.curTime + rnd_float(defenderSpawnedSpawnBlock))
    elif defendersCount > defendersCountRequired
      let defenderIdx = rnd_int(0, defendersCount - 1)
      query(defendersList[defenderIdx]) <| $ [es] (var invisible_man__forceVanish : bool&)
        invisible_man__forceVanish = true
        defendersList |> erase(defenderIdx)
        defendersSpawnBlockedUntil = max(defendersSpawnBlockedUntil, act.curTime + rnd_float(defenderVanishedSpawnBlock))


[es(tag=server)]
def extraction_point_defence_controller_on_hero_extracted(evt : EventHeroExtracted;
                                                          eid aka portal_eid : EntityId;
                                                          extraction_point_defence_controller__enabled : bool;
                                                          extraction_point_defence_controller__defendersCountMinMax : int2;
                                                          extraction_point_defence_controller__heroExtractedSpawnBlock : float2;
                                                          var extraction_point_defence_controller__defendersCountRequired : int&;
                                                          var extraction_point_defence_controller__defendersSpawnBlockedUntil : float&)
  if !extraction_point_defence_controller__enabled
    return

  assume defendersSpawnBlockedUntil = extraction_point_defence_controller__defendersSpawnBlockedUntil
  assume defendersCountRequired = extraction_point_defence_controller__defendersCountRequired
  assume defendersCountMinMax = extraction_point_defence_controller__defendersCountMinMax
  assume heroExtractedSpawnBlock = extraction_point_defence_controller__heroExtractedSpawnBlock

  if portal_eid == evt.portalEid
    defendersCountRequired = min(defendersCountRequired + 1, defendersCountMinMax.y)
    defendersSpawnBlockedUntil = max(defendersSpawnBlockedUntil, get_sync_time() + rnd_float(heroExtractedSpawnBlock))
  else
    defendersCountRequired = max(defendersCountRequired - 1, defendersCountMinMax.x)

