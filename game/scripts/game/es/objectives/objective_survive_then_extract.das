require ecs
require game.es.extraction_point.extraction_point_common


let PHASE_SURVIVE = 0
let PHASE_EXTRACT = 1


[es(tag=server, on_appear, on_event=EventLevelLoaded, REQUIRE=objectiveSurviveThenExtract)]
def contract_survive_then_extract(evt : Event; objective__playerEid : EntityId; var phased_objective__currentPhase : int&)
  let hasExistingExtraction = find_query() <| $ [es(REQUIRE=extraction_point)] (extraction__currentState : int; eid aka extraction_eid : EntityId)
    return extraction__currentState != int(ExtractionPointState.DISABLED) && is_extraction_for_player(objective__playerEid, extraction_eid)
  phased_objective__currentPhase = hasExistingExtraction ? PHASE_EXTRACT : PHASE_SURVIVE


[es(tag=server, on_appear, track=extraction__currentState, REQUIRE=extraction_point)]
def contract_survive_then_extract_track_appeared_extraction(evt : Event; eid aka extraction_eid : EntityId; extraction__currentState : int)
  if extraction__currentState == int(ExtractionPointState.DISABLED)
    return
  query() <| $ [es(REQUIRE=objectiveSurviveThenExtract)] (objective__playerEid : EntityId; var phased_objective__currentPhase : int&)
    if phased_objective__currentPhase == PHASE_EXTRACT
      return
    if is_extraction_for_player(objective__playerEid, extraction_eid)
      phased_objective__currentPhase = PHASE_EXTRACT
