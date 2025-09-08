require ecs
require app
require math.base
require game.events.events_active_matter
require game.events.events_game
require game.events.player_events
require game.es.hit_result_common
require game.events.events


[es(tag=server, no_order)]
def player_move_track(info : UpdateStageInfoAct;
                      possessed : EntityId;
                      player_move_track__checkInterval,
                      player_move_track__minDistanceToRecord,
                      scoring_player__firstSpawnTime : float;
                      var player_move_tracker__trackPoints : Array;
                      var player_move_track__lastCheckedPosition : float3&;
                      var player_move_track__nextCheckAt : float&;
                      var scoring_player__playerPathLen : float&)
  if (player_move_track__nextCheckAt > info.curTime)
    return

  player_move_track__nextCheckAt = info.curTime + player_move_track__checkInterval

  query(possessed) <| $ [es] (transform : float3x4)
    let trackLenSq = square(player_move_track__minDistanceToRecord)
    let distanceSq = distance_sq(transform[3], player_move_track__lastCheckedPosition)

    if distanceSq < trackLenSq
      return

    using() <| $(var point : Object)
      point |> set("timestamp", info.curTime - scoring_player__firstSpawnTime)
      point |> set("position", transform[3])
      point |> set("eventType", "positionPoint")
      player_move_tracker__trackPoints |> push(point)

    scoring_player__playerPathLen += distance(transform[3], player_move_track__lastCheckedPosition)
    player_move_track__lastCheckedPosition = transform[3]


[es(tag=server)]
def player_trans_portal_track(evt : EventTransPortalTeleport;
                              scoring_player__firstSpawnTime : float;
                              var player_move_track__lastCheckedPosition : float3&;
                              var player_move_tracker__trackPoints : Array;
                              var scoring_player__playerPathLen : float&)
  let timeStamp = get_sync_time() - scoring_player__firstSpawnTime
  using() <| $(var pointFrom : Object)
    pointFrom |> set("timestamp", timeStamp)
    pointFrom |> set("position", evt.from)
    pointFrom |> set("eventType", "transPortalFrom")
    pointFrom |> set("eid", evt.entry)
    player_move_tracker__trackPoints |> push(pointFrom)

  using() <| $(var pointTo : Object)
    pointTo |> set("timestamp", timeStamp)
    pointTo |> set("position", evt.to)
    pointTo |> set("eventType", "transPortalTo")
    pointTo |> set("eid", evt.exit)
    player_move_tracker__trackPoints |> push(pointTo)

  scoring_player__playerPathLen += distance(player_move_track__lastCheckedPosition, evt.from)
  player_move_track__lastCheckedPosition = evt.to


[es(tag=server, before=extraction_hero_extracted_server)] // extraction_hero_extracted_server destroys possessed
def player_extracted_track(evt : CmdExtractFromBattlefieldServer;
                           possessed : EntityId;
                           scoring_player__firstSpawnTime : float;
                           player_move_track__lastCheckedPosition : float3;
                           var player_move_tracker__trackPoints : Array;
                           var scoring_player__playerPathLen : float&;
                           var scoring_player__playTime : float2&)
  query(possessed) <| $ [es] (transform : float3x4)
    let timeStamp = get_sync_time() - scoring_player__firstSpawnTime
    using() <| $(var extractionInfo : Object)
      extractionInfo |> set("timestamp", timeStamp)
      extractionInfo |> set("position", transform[3])
      extractionInfo |> set("eventType", "extracted")
      player_move_tracker__trackPoints |> push(extractionInfo)
    scoring_player__playerPathLen += distance(player_move_track__lastCheckedPosition, transform[3])
    scoring_player__playTime.x += timeStamp - scoring_player__playTime.y


[es(tag=server, before=raid_player_killed, REQUIRE_NOT=nexus_militant)]
def player_killed_track(evt : EventEntityDied; possessedByPlr aka victim_possessedByPlr : EntityId; transform : float3x4)
  query(victim_possessedByPlr) <| $ [es] (scoring_player__firstSpawnTime : float;
                                          player_move_track__lastCheckedPosition : float3;
                                          var player_move_tracker__trackPoints : Array;
                                          var scoring_player__playerPathLen : float&;
                                          var scoring_player__playTime : float2&)
    let timeStamp = get_sync_time() - scoring_player__firstSpawnTime
    using() <| $(var deathInfo : Object)
      deathInfo |> set("timestamp", timeStamp)
      deathInfo |> set("position", transform[3])
      deathInfo |> set("eventType", "died")
      if evt.offender != evt.victim
        query(evt.offender) <| $ [es] (possessedByPlr aka offender_possessedByPlr : EntityId = INVALID_ENTITY_ID; kill_tracking_tag : string)
          deathInfo |> set("offenderType", kill_tracking_tag)
          query(offender_possessedByPlr) <| $ [es] (name : string)
            print("[MOVE TRACK] player <{victim_possessedByPlr}> killed by player <{offender_possessedByPlr}> {name} (hero={evt.offender})")
            deathInfo |> set("name", name)
      player_move_tracker__trackPoints |> push(deathInfo)
      scoring_player__playerPathLen += distance(player_move_track__lastCheckedPosition, transform[3])
      scoring_player__playTime.x += timeStamp - scoring_player__playTime.y


[es(tag=server, before=raid_save_player_data_on_session_finished, on_event=EventSessionFinished, REQUIRE_NOT=nexus_player, REQUIRE=player)]
def fake_death_for_battle_result_on_session_finished(evt : Event;
                                                     possessed : EntityId;
                                                     scoring_player__firstSpawnTime : float;
                                                     player_move_track__lastCheckedPosition : float3;
                                                     var player_move_tracker__trackPoints : Array;
                                                     var scoring_player__playerPathLen : float&)
  query(possessed) <| $ [es] (isAlive : bool; transform : float3x4)
    if !isAlive
      return
    let timeStamp = get_sync_time() - scoring_player__firstSpawnTime
    using() <| $(var deathInfo : Object)
      deathInfo |> set("timestamp", timeStamp)
      deathInfo |> set("position", transform[3])
      deathInfo |> set("eventType", "died")
      player_move_tracker__trackPoints |> push(deathInfo)
    scoring_player__playerPathLen += distance(player_move_track__lastCheckedPosition, transform[3])


// this instead of tracking possessed, not to trigger on reconnect
[es(tag=server)]
def player_spawn_track(evt : CmdPossessEntity;
                       scoring_player__firstSpawnTime : float;
                       var player_move_track__lastCheckedPosition : float3&;
                       var scoring_player__playTime : float2&;
                       var player_move_tracker__trackPoints : Array)
  let timeStamp = scoring_player__firstSpawnTime <= 0.0 ? 0.0 : get_sync_time() - scoring_player__firstSpawnTime
  query(evt.possessedEid) <| $ [es] (transform : float3x4;
                                     player_controlled_monster : Tag const?;
                                     item__name : das_string const?)
    using() <| $(var spawnInfo : Object)
      spawnInfo |> set("timestamp", timeStamp)
      spawnInfo |> set("position", transform[3])
      if player_controlled_monster == null
        spawnInfo |> set("eventType", "respawned")
        scoring_player__playTime.y = timeStamp
      else
        spawnInfo |> set("eventType", "transformed")
        if item__name != null
          spawnInfo |> set("monsterType", *item__name)
      player_move_tracker__trackPoints |> push(spawnInfo)
    player_move_track__lastCheckedPosition = transform[3]


[es(tag=server, before=interesting_encounter_zone_enter)]
def player_visit_encounters_track(evt : EventZoneEnter; base_interesting_encounter__visitorsList : EidList)
  query(evt.visitorEid) <| $ [es] (possessedByPlr : EntityId; isAlive : bool; transform : float3x4)
    if !isAlive || has_value(base_interesting_encounter__visitorsList, possessedByPlr)
      return

    query(possessedByPlr) <| $[es] (scoring_player__firstSpawnTime : float;
                                    var player_move_tracker__trackPoints : Array)
      let timeStamp = get_sync_time() - scoring_player__firstSpawnTime
      using() <| $(var encounterVisitInfo : Object)
        encounterVisitInfo |> set("timestamp", timeStamp)
        encounterVisitInfo |> set("position", transform[3])
        encounterVisitInfo |> set("eventType", "encounterVisit")
        player_move_tracker__trackPoints |> push(encounterVisitInfo)


[es(tag=server)]
def player_kills_track(evt : EventAnyEntityDied)
  if evt.offender == evt.victim
    return
  query(evt.offender) <| $ [es] (possessedByPlr aka offender_possessedByPlr : EntityId; transform aka offender_transform : float3x4)
    query(offender_possessedByPlr) <| $ [es] (scoring_player__firstSpawnTime : float;
                                              var player_move_tracker__trackPoints : Array)
      let timeStamp = get_sync_time() - scoring_player__firstSpawnTime
      query(evt.victim) <| $ [es] (kill_tracking_tag : string;
                                   transform aka victim_transform : float3x4;
                                   possessedByPlr aka victim_possessedByPlr : EntityId = INVALID_ENTITY_ID;
                                   hide_player_name : Tag const?)
        using() <| $(var killInfo : Object)
          killInfo |> set("timestamp", timeStamp)
          killInfo |> set("position", offender_transform[3])
          killInfo |> set("victimPosition", victim_transform[3])
          killInfo |> set("eventType", "kill")
          killInfo |> set("victimType", kill_tracking_tag)
          query(victim_possessedByPlr) <| $ [es] (name : string)
            print("[MOVE TRACK] player <{offender_possessedByPlr}> killed player <{victim_possessedByPlr}> {name} (hero={evt.victim})")
            if hide_player_name == null
              killInfo |> set("name", name)
          player_move_tracker__trackPoints |> push(killInfo)


[es(tag=server, before=hive_body_destruction)]
def player_destroyed_hive_track(evt : EventOnRendinstDestruction;
                                hive_body__destructionTriggered : bool;
                                transform aka hive_transform : float3x4;
                                riOffender : EntityId)
  if hive_body__destructionTriggered
    return
  query(riOffender) <| $ [es] (possessedByPlr : EntityId;
                               transform aka hero_transform : float3x4)
    query(possessedByPlr) <| $ [es] (scoring_player__firstSpawnTime : float;
                                     var player_move_tracker__trackPoints : Array)
      let timestamp = get_sync_time() - scoring_player__firstSpawnTime
      using() <| $(var killInfo : Object)
        killInfo |> set("timestamp", timestamp)
        killInfo |> set("position", hero_transform[3])
        killInfo |> set("victimPosition", hive_transform[3])
        killInfo |> set("eventType", "kill")
        killInfo |> set("victimType", "beehive")
        player_move_tracker__trackPoints |> push(killInfo)


[es(tag=server)]
def player_track_healing(evt : EventHealItemUsed;
                         item__humanOwnerEid : EntityId)
  query(item__humanOwnerEid) <| $ [es] (possessedByPlr : EntityId)
    query(possessedByPlr) <| $ [es] (var scoring_player__medicineUsed : int&)
      scoring_player__medicineUsed += 1


[es(tag=server)]
def player_track_opened_containers(evt : EventExternalInventoryContainerAccessedByHero; eid aka container_eid : EntityId)
  query(evt.heroEid) <| $ [es] (possessedByPlr : EntityId)
    query(possessedByPlr) <| $ [es] (var player__usedContainers : EidList;
                                     var scoring_player__lootedSecretContainers : int&;
                                     var scoring_player__lootedBodies : int&;
                                     var scoring_player__lootedCommonContainers : int&)
      if has_value(player__usedContainers, container_eid)
        return

      player__usedContainers |> push(container_eid)

      if has(container_eid, "secret_lootable_rendinst")
        scoring_player__lootedSecretContainers += 1
      elif has(container_eid, "lootable_ragdoll_phys_obj")
        scoring_player__lootedBodies += 1
      else
        scoring_player__lootedCommonContainers += 1


[es(tag=server)]
def player_track_received_damage(evt : EventDamageModelApplyDamage; possessedByPlr : EntityId)
  query(possessedByPlr) <| $ [es] (var scoring_player__receivedDamage : float&)
    scoring_player__receivedDamage += evt.notBlockedDamage


[es(tag=server)]
def player_track_deal_damage_damage_model(evt : EventOnEntityHit)
  if evt.hitResult == int(HitResult.HIT_RES_NONE)
    return

  if evt.offender == evt.victim
    return

  query(evt.offender) <| $ [es] (possessedByPlr : EntityId)
    query(possessedByPlr) <| $ [es] (var scoring_player__dealtDamage : float&)
      scoring_player__dealtDamage += evt.deltaHp
