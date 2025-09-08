require ecs
require app
require Grid
require math.base
require math.easing
require DagorMath
require ecs.soa_template
require game.utils.hero
require game.events.events_active_matter
require game.es.extraction_point.extraction_point_common
require game.es.extraction_point.extraction_enums_common


[es(tag=gameClient, REQUIRE=hero, after=hero_human_pre_use_object_es, before=human_use_action_es)]
def select_nearest_extraction_point(act : UpdateStageInfoAct;
                                    eid aka hero_eid : EntityId;
                                    transform aka hero_transform : float3x4;
                                    var human_use_object__selectedObject : EntityId&;
                                    var human_use_object__canUseSelected : bool&)
  find_query() <| $ [es] (eid aka portal_eid : EntityId;
                          transform aka portal_transform : float3x4;
                          extraction__extracting : bool;
                          extraction__currentState : int;
                          extraction__useDistance : float;
                          extraction__useHintOk, extraction__useHintWrongTime, extraction__useHintPrimaryContract : string;
                          var item__useActionAvailable : bool&;
                          var item__setCustomUsePrompt : das_string&;
                          final_extraction_point : Tag const?)
    let isNear = distance_sq(portal_transform[3], hero_transform[3]) <= square(extraction__useDistance)
    if extraction__currentState != int(ExtractionPointState.DISABLED) && !extraction__extracting && isNear
      if final_extraction_point != null || is_extraction_for_hero(hero_eid, portal_eid)
        human_use_object__selectedObject = portal_eid
        human_use_object__canUseSelected = true
        let reason = hero_can_be_extracted(hero_eid, portal_eid)
        if final_extraction_point != null || reason == ExtractionStatusForHero.OK
          item__useActionAvailable = true
          item__setCustomUsePrompt := extraction__useHintOk
        else
          item__useActionAvailable = false
          if reason == ExtractionStatusForHero.WRONG_TIME
            item__setCustomUsePrompt := extraction__useHintWrongTime
          elif reason == ExtractionStatusForHero.PRIMARY_CONTRACT_NOT_COMPLETED
            item__setCustomUsePrompt := extraction__useHintPrimaryContract
        return true
    return false


[es(tag=gameClient, REQUIRE=hero, on_appear)]
def init_hero_portal_status(evt : Event;
                            eid aka hero_eid : EntityId)
  query() <| $ [es] (eid aka portal_eid : EntityId;
                     var extraction__statusForHero : int&)
    extraction__statusForHero = int(hero_can_be_extracted(hero_eid, portal_eid))


[es(tag=gameClient, on_appear)]
def init_portal_status_for_hero(evt : Event;
                                eid aka portal_eid : EntityId;
                                var extraction__statusForHero : int&)
  query() <| $ [es(REQUIRE=hero)] (eid aka hero_eid : EntityId)
    extraction__statusForHero = int(hero_can_be_extracted(hero_eid, portal_eid))


[es(tag=gameClient, on_appear, on_disappear, track=(objective__isCompleted, objective__isFailed), REQUIRE=(objective__isCompleted, objective__isFailed))]
def update_portal_status_for_hero(evt : Event)
  query() <| $ [es(REQUIRE=hero)] (eid aka hero_eid : EntityId)
    query() <| $ [es] (eid aka portal_eid : EntityId;
                       var extraction__statusForHero : int&)
      extraction__statusForHero = int(hero_can_be_extracted(hero_eid, portal_eid))


[es(tag=server, track=possessed, on_appear)]
def update_extraction_enable_time_server(evt : Event;
                                         eid aka player_eid : EntityId;
                                         possessed : EntityId)
  if possessed == INVALID_ENTITY_ID
    return

  query() <| $ [soa_blk, es] (extraction_enable_time__defaultTime : float;
                              var extractionEnableTimes : ExtractionEnableTime_SOA)
    var found = false
    for i in iter_range(extractionEnableTimes)
      if extractionEnableTimes[i].extraction_enable_time__player == player_eid
        found = true
        break

    let enableTime = get_sync_time() + extraction_enable_time__defaultTime
    extractionEnableTimes |> push() <| ExtractionEnableTime(
      extraction_enable_time__player = player_eid,
      extraction_enable_time__forPlayerAt = enableTime)


[es(tag=gameClient, REQUIRE=hero, on_appear)]
def update_extraction_enable_time_client(evt : Event)
  query() <| $ [soa_blk, es] (extraction_enable_time__defaultTime : float;
                              var extraction_enable_time__at : float&)
    if extraction_enable_time__at >= 0.0
      return
    let enableTime = get_sync_time() + extraction_enable_time__defaultTime
    extraction_enable_time__at = enableTime


[es(tag=server, REQUIRE=disable_extraction_point_when_inactive, no_order)]
def disable_extraction_point_when_inactive(act : UpdateStageInfoAct;
                                           eid : EntityId;
                                           var extraction__currentState : int&;
                                           var extraction__extractionProgress : float&;
                                           var extraction__extracting : bool&)
  if (extraction__currentState == int(ExtractionPointState.DISABLED) ||
    extraction__currentState == int(ExtractionPointState.INACTIVE))
    extraction__currentState = int(ExtractionPointState.DISABLED)
    extraction__extractionProgress = 0.0
    extraction__extracting = false
    removeSubTemplate(eid, "disable_extraction_point_when_inactive")