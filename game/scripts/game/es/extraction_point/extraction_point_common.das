module extraction_point_common shared
require DagorSystem
require ecs
require app
require DagorRandom
require ecs.soa_template
require game.es.objectives_enums_common
require game.events.events_active_matter
require game.es.objectives.objective_common
require game.es.extraction_point.extraction_enums_common


[soa_template]
struct ExtractionEnableTime
  extraction_enable_time__player : EntityId
  extraction_enable_time__forPlayerAt : float


enum ExtractionPointState
  DISABLED
  INACTIVE
  ACTIVATING
  ACTIVE
  DEACTIVATING


def is_extraction_for_spawn_group(extraction_eid : EntityId; team__spawnGroupId : int)
  var res = false
  query(extraction_eid) <| $ [es] (extraction__connectedSpawnGroups : IntList;
                                   extraction_for_everyone : Tag const?)
    if extraction_for_everyone != null
      res = true
      return

    res = extraction__connectedSpawnGroups |> has_value(team__spawnGroupId)
  return res


def is_extraction_for_team(extraction_eid, team_eid : EntityId)
  var res = false
  query(team_eid) <| $ [es] (team__spawnGroupId : int = -1)
    res = is_extraction_for_spawn_group(extraction_eid, team__spawnGroupId)
  return res


def is_extraction_for_player(player_eid, extraction_eid : EntityId)
  var res = false
  query(player_eid) <| $ [es] (team : int)
    find_query() <| $ [es] (team__spawnGroupId : int = -1; team__id : int)
      if team == team__id
        res = is_extraction_for_spawn_group(extraction_eid, team__spawnGroupId)
        return true
      return false
  return res


def is_extraction_for_hero(hero_eid, extraction_eid : EntityId)
  return is_extraction_for_player(hero_eid, extraction_eid) // will use team comp from hero_eid


def activate_final_extraction_points()
  query() <| $ [es(REQUIRE=final_extraction_point)] (var extraction__currentState : int&)
    extraction__currentState = int(ExtractionPointState.INACTIVE)


def activate_random_final_extraction_point()
  var possibleExtractionPoints : array<EntityId>
  query() <| $ [es(REQUIRE=final_extraction_point)] (eid : EntityId; extraction__currentState : int)
    if extraction__currentState == int(ExtractionPointState.DISABLED)
      possibleExtractionPoints |> push(eid)
  if length(possibleExtractionPoints) == 0
    logerr("[Extraction Points] Failed to find any final extraction points")
    return INVALID_ENTITY_ID
  let finalExtractionEid = possibleExtractionPoints[grnd() % length(possibleExtractionPoints)]
  query(finalExtractionEid) <| $ [es] (var extraction__currentState : int&)
    extraction__currentState = int(ExtractionPointState.INACTIVE)
  return finalExtractionEid


[soa_def]
def private get_extraction_enable_time_for_player(player_eid : EntityId;
                                                  extractionEnableTimes : ExtractionEnableTime_SOA;
                                                  defaultTime : float)
  for extractionEnableTime in extractionEnableTimes
    if extractionEnableTime.extraction_enable_time__player == player_eid
      return extractionEnableTime.extraction_enable_time__forPlayerAt
  return defaultTime


def get_extraction_enable_time_for_player(player_eid : EntityId;
                                          extraction_eid : EntityId)
  var enableTime = 0.0
  query(extraction_eid) <| $ [soa_blk, es] (extractionEnableTimes : ExtractionEnableTime_SOA;
                                            extraction_enable_time__defaultTime = 0.0)
    enableTime = get_extraction_enable_time_for_player(player_eid, extractionEnableTimes, extraction_enable_time__defaultTime)
  return enableTime


def hero_can_be_extracted(hero_eid, extraction_eid : EntityId) : ExtractionStatusForHero
  var result = ExtractionStatusForHero.OK
  query(hero_eid) <| $ [es(REQUIRE=heroForPlayer)] (possessedByPlr : EntityId)
    if get_extraction_enable_time_for_player(possessedByPlr, extraction_eid) > get_sync_time()
      result = ExtractionStatusForHero.WRONG_TIME
      return
    if !(extraction_eid |> has("final_extraction_point"))
      var exitContactCompleted = false
      for_each_player_objective(possessedByPlr) <| $(objective_eid : EntityId)
        query(objective_eid) <| $ [es] (objective__id : string; objective__isCompleted : bool; objective__isFailed : bool)
          if objective__id == "0" && (objective__isCompleted || objective__isFailed)
            exitContactCompleted = true
      if !exitContactCompleted
        result = ExtractionStatusForHero.PRIMARY_CONTRACT_NOT_COMPLETED
        return

  return result


def start_extraction_sequence(heroEid : EntityId;
                              portalEid : EntityId)
  if !is_extraction_for_hero(heroEid, portalEid)
    return
  query(portalEid) <| $ [es] (transform aka portal_transform : float3x4;
                              extraction__radiusMinMax : float2;
                              extraction__extractionSequenceTemplate : string)
    query(heroEid) <| $ [es] (possessedByPlr : EntityId; transform : float3x4)

      if distance_sq(transform[3], portal_transform[3]) > extraction__radiusMinMax.y * extraction__radiusMinMax.y
        return

      let extractionEnableTime = get_extraction_enable_time_for_player(possessedByPlr, portalEid)
      if get_sync_time() < extractionEnableTime
        return

      broadcastEvent(EventHeroExtracted(heroEid = heroEid, portalEid = portalEid))

      let testMode = has(portalEid, "debug_portal__doNotExtract")
      createEntity(extraction__extractionSequenceTemplate) <| $(var init)
        init |> set("game_effect__attachedTo", heroEid)
        init |> set("extraction_sequence_affect__testMode", testMode)


def update_active_extraction_point(extraction_eid, hero_eid : EntityId;
                                   extraction_current_state : int;
                                   extraction__forceMapVisible : bool)
  if (extraction_current_state != int(ExtractionPointState.DISABLED) || extraction__forceMapVisible) && is_extraction_for_hero(hero_eid, extraction_eid)
    if !(extraction_eid |> has("extraction__hudPoint"))
      extraction_eid |> addSubTemplate("active_extraction_point")
  elif extraction_eid |> has("extraction__hudPoint")
    extraction_eid |> removeSubTemplate("active_extraction_point")
