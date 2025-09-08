require ecs
require app
require Grid
require DngNet
require DagorMath
require game.events.events
require game.events.events_game
require game.events.events_active_matter
require game.es.extraction_point.extraction_point_common
require game.es.extraction_point.extraction_enums_common


[es(tag=server)]
def extraction_hero_init_extraction(evt : CmdUse;
                                    eid : EntityId;
                                    var extraction__extracting : bool&)
  extraction__extracting = hero_can_be_extracted(evt.requesterEid, eid) == ExtractionStatusForHero.OK


[es(tag=server, no_order)]
def extraction_point_update(act : ParallelUpdateFrameDelayed;
                            eid aka portal_eid : EntityId;
                            extraction__radiusMinMax : float2;
                            extraction__extractionTime : float;
                            transform aka portal_transform : float3x4;
                            extraction__updateInterval : float;
                            extraction__activePhaseDelay : float;
                            extraction__closeModifier : float;
                            var extraction__extracting : bool&;
                            var extraction__timers : EidList;
                            var extraction__nextUpdateAt : float&;
                            var extraction__currentState : int&;
                            var extraction__extractionProgress : float&;
                            var extraction__activationStartsAt : float&)
  if extraction__currentState == int(ExtractionPointState.DISABLED) || !extraction__extracting
    return

  if act.curTime >= extraction__nextUpdateAt
    extraction__nextUpdateAt = act.curTime + extraction__updateInterval

    var trackedHeroes : array<EntityId>
    var idx = extraction__timers |> length()

    let leaveRadiusSq = extraction__radiusMinMax.y * extraction__radiusMinMax.y

    while idx > 0
      idx--
      query(extraction__timers[idx]) <| $ [es] (game_effect__attachedTo : EntityId;
                                                extraction_preparing_affect__extractAt : float)
        query(game_effect__attachedTo) <| $ [es] (possessedByPlr : EntityId;
                                                  transform : float3x4;
                                                  isAlive : bool = true)
          let checkDistance = distance_sq(transform[3], portal_transform[3]) > leaveRadiusSq
          let checkTime = act.curTime > extraction_preparing_affect__extractAt
          let extractionEnableTime = get_extraction_enable_time_for_player(possessedByPlr, portal_eid)
          let checkEnableTime = extractionEnableTime <= act.curTime
          if checkTime || checkDistance || !isAlive || !checkEnableTime
            destroyEntity(extraction__timers[idx])
            extraction__timers |> erase(idx)
          trackedHeroes |> push(game_effect__attachedTo)

    let enterRadius = extraction__radiusMinMax.x
    for_each_entity_in_grid(ecs_hash("humans"), BSphere3(portal_transform[3], enterRadius), GridEntCheck.POS) <| $(smEid : EntityId)
      if has_value(trackedHeroes, smEid) || !is_extraction_for_hero(smEid, portal_eid)
        return

      let isExtracting = find_query() <| $ [es(REQUIRE=extraction_sequence_affect)] (game_effect__attachedTo aka sequence_game_effect__attachedTo : EntityId)
        return sequence_game_effect__attachedTo == smEid

      if isExtracting
        return

      let stateInactive = extraction__currentState == int(ExtractionPointState.INACTIVE)
      let timeExtraction = stateInactive ? act.curTime + extraction__extractionTime : extraction__activationStartsAt

      query(smEid) <| $ [es(REQUIRE=heroForPlayer)] (possessedByPlr : EntityId; isAlive : bool = true)
        let extractionEnableTime = get_extraction_enable_time_for_player(possessedByPlr, portal_eid)
        if !isAlive || act.curTime < extractionEnableTime
          return
        let timerEid = createEntity("extraction_preparing_affect") <| $(var init)
          init |> set("extraction_preparing_affect__startedAt", act.curTime)
          init |> set("extraction_preparing_affect__extractAt", timeExtraction)
          init |> set("game_effect__attachedTo", smEid)
          init |> set("game_effect__portalEid", portal_eid)
        extraction__timers |> push(timerEid)

  if extraction__currentState == int(ExtractionPointState.INACTIVE)
    extraction__activationStartsAt = act.curTime + extraction__extractionTime
    extraction__currentState = int(ExtractionPointState.ACTIVATING)
  elif extraction__currentState == int(ExtractionPointState.ACTIVATING)
    extraction__extractionProgress = min(1.0, extraction__extractionProgress + safediv(act.dt, extraction__extractionTime))
    if extraction__extractionProgress >= 1.0
      extraction__currentState = int(ExtractionPointState.ACTIVE)
  elif extraction__currentState == int(ExtractionPointState.ACTIVE)
    if extraction__activationStartsAt > 0.0 && act.curTime >= extraction__activationStartsAt + extraction__activePhaseDelay
      extraction__currentState = int(ExtractionPointState.DEACTIVATING)
  elif extraction__currentState == int(ExtractionPointState.DEACTIVATING)
    extraction__extractionProgress = max(0.0, extraction__extractionProgress - safediv(act.dt * extraction__closeModifier, extraction__extractionTime))
    if extraction__extractionProgress <= 0.0
      extraction__currentState = int(ExtractionPointState.INACTIVE)
      extraction__extracting = false


[es(tag=server)]
def extraction_hero_extracted_server(evt : CmdExtractFromBattlefieldServer;
                                     possessed : EntityId;
                                     var scoring_player__isExtractedSuccess : bool&)
  if evt.isDebug
    return
  scoring_player__isExtractedSuccess = true
  destroyEntity(possessed)


[es(tag=gameClient)]
def extraction_hero_extracted_client(evt : CmdExtractFromBattlefield; eid, possessed : EntityId)
  if possessed |> has("hero")
    send_net_event(eid, EnableSpectatorForPlayer(target = INVALID_ENTITY_ID))


[es(tag=server, on_disappear)]
def extraction_hero_extract(evt : Event;
                            extraction_preparing_affect__extractAt : float;
                            game_effect__attachedTo : EntityId;
                            game_effect__portalEid : EntityId)
  if extraction_preparing_affect__extractAt > get_sync_time()
    return
  start_extraction_sequence(game_effect__attachedTo, game_effect__portalEid)
