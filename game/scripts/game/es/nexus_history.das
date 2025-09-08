require app
require ecs
require ecs.common
require player
require DngDm
require DngNet
require game.es.nexus_common
require game.events.events_game
require game.events.events_active_matter
require game.es.damage_systems.damage_model_common
require game.es.nexus_history_common
require game.es.nexus_round_mode_common


[es(tag=gameClient, on_appear)]
def nexus_history_victim_local_init(evt : Event;
                                    eid : EntityId;
                                    nexus_history__victim : EntityId)
  let localPlayer = get_local_player_eid()
  if localPlayer == nexus_history__victim
    addSubTemplate(eid, "nexus_history_victim_local")
    return


[es(tag=gameClient, on_appear)]
def nexus_history_offender_local_init(evt : Event;
                                      eid : EntityId;
                                      nexus_history__offender : EntityId)
  let localPlayer = get_local_player_eid()
  if localPlayer == nexus_history__offender
    addSubTemplate(eid, "nexus_history_offender_local")
    return


[es(tag=gameClient, on_appear)]
def nexus_history_assist_local_init(evt : Event;
                                    eid : EntityId;
                                    nexus_history__assists : EidList)
  let localPlayer = get_local_player_eid()
  if find_index(nexus_history__assists, localPlayer) != -1
    addSubTemplate(eid, "nexus_history_assist_local")
    return


[es(tag=gameClient, on_appear)]
def nexus_history_participant_local_init(evt : Event;
                                         eid : EntityId;
                                         nexus_history__participants : EidList)
  let localPlayer = get_local_player_eid()
  if find_index(nexus_history__participants, localPlayer) != -1
    addSubTemplate(eid, "nexus_history_participant_local")
    return


[es(tag=server, REQUIRE=(nexus_history, nexus_history_active), on_appear)]
def nexus_history_round_init(evt : Event;
                             eid : EntityId)
  let nexusRoundNumber = get_round_number()
  if nexusRoundNumber == 0
    return
  remote_add_sub_template(eid, "nexus_history_round") <| $(var init)
    init |> set("nexus_history__round", nexusRoundNumber)


[es(tag=server, REQUIRE=(nexus_history_active, nexus_history__round))]
def nexus_history_active_reset(evt : EventNexusRoundModeRoundChange;
                               eid : EntityId)
  remote_remove_sub_template(eid, "nexus_history_active")


[es(tag=server, REQUIRE=nexus_game_controller)]
def nexus_history_round_winner_create(evt : EventNexusRoundModeRoundFinished)
  createEntity("nexus_history_winner+nexus_history_winner_reason+nexus_history_round+nexus_history_active") <| $(var init)
    init |> set("nexus_history__team", evt.winnerTeam)
    init |> set("nexus_history__winReason", evt.reason)
    init |> set("nexus_history__at", evt.time)


[es(tag=server, REQUIRE=nexus_game_controller)]
def nexus_history_game_winner_create(evt : EventNexusGameEnd)
  createEntity("nexus_history_winner") <| $(var init)
    init |> set("nexus_history__team", evt.winner)
    init |> set("nexus_history__at", evt.time)


[es(tag=server, REQUIRE=nexus_game_controller, REQUIRE_NOT=deadEntity)]
def nexus_history_hit_track(evt : EventOnEntityHit)
  if evt.deltaHp <= 0.0
    return

  var victimPlr = INVALID_ENTITY_ID
  var offenderPlr = INVALID_ENTITY_ID
  var victimTeam = TEAM_UNASSIGNED
  var offenderTeam = TEAM_UNASSIGNED
  query(evt.victim) <| $ [es(REQUIRE_NOT=deadEntity)] (possessedByPlr : EntityId;
                                                       team : int)
    victimPlr = possessedByPlr
    victimTeam = team
  query(evt.offender) <| $ [es] (possessedByPlr : EntityId;
                                 team : int)
    offenderPlr = possessedByPlr
    offenderTeam = team
  if victimPlr == INVALID_ENTITY_ID
    return

  let selfHit = victimPlr == offenderPlr
  let teamHit = victimTeam == offenderTeam

  var hitTemplate = "nexus_history_hit+nexus_history_active"
  if selfHit
    hitTemplate = add_sub_template_name(hitTemplate, "nexus_history_hit_self")
  if teamHit
    hitTemplate = add_sub_template_name(hitTemplate, "nexus_history_hit_team")

  createEntity(hitTemplate) <| $(var init)
    init |> set("nexus_history__offender", offenderPlr)
    init |> set("nexus_history__victim", victimPlr)
    init |> set("nexus_history__damage", evt.deltaHp)
    init |> set("nexus_history__at", get_sync_time())


[es(tag=server, REQUIRE=nexus_militant)]
def nexus_history_kill_create(evt : EventEntityDied;
                              possessedByPlr : EntityId;
                              transform aka victim_transform : float3x4;
                              team aka victim_team : int;
                              var human_damage_model__parts : Object)
  if !is_game_started()
    return

  var offenderPlr = INVALID_ENTITY_ID
  var offenderTeam = TEAM_UNASSIGNED
  var killDistanceSq = 0.0
  query(evt.offender) <| $ [es] (possessedByPlr : EntityId;
                                 transform : float3x4;
                                 team : int)
    offenderPlr = possessedByPlr
    offenderTeam = team
    killDistanceSq = distance_sq(victim_transform[3], transform[3])


  let suicide = possessedByPlr == offenderPlr
  let teamKill = victim_team == offenderTeam
  let grenadeKill = evt.damageType == int(DamageType.DM_EXPLOSION)
  let meleeKill = evt.damageType == int(DamageType.DM_MELEE)
  var headshotKill = false
  var head : BodyPart
  var obj = getRW_ecs_object(human_damage_model__parts["head"])
  if obj != null
    head = make_object_of_body_part("head", *obj, human_damage_model__parts)
    headshotKill = has_value(*head.nodesIds, evt.collNodeId)
  var longshotKill = false
  find_query() <| $ [es] (nexus_stats_rules__longshotKillDistanceSq : float)
    longshotKill = killDistanceSq > nexus_stats_rules__longshotKillDistanceSq
    return true

  var killTemplate = "nexus_history_kill+nexus_history_active"
  if suicide
    killTemplate = add_sub_template_name(killTemplate, "nexus_history_kill_suicide")
  if teamKill
    killTemplate = add_sub_template_name(killTemplate, "nexus_history_kill_teamkill")
  if grenadeKill
    killTemplate = add_sub_template_name(killTemplate, "nexus_history_kill_grenade")
  if meleeKill
    killTemplate = add_sub_template_name(killTemplate, "nexus_history_kill_melee")
  if longshotKill
    killTemplate = add_sub_template_name(killTemplate, "nexus_history_kill_longshot")
  if headshotKill
    killTemplate = add_sub_template_name(killTemplate, "nexus_history_kill_headshot")

  using() <| $(var playersWithAssist : EidList)
    query_players_with_assist(possessedByPlr, offenderPlr, victim_team, get_sync_time()) <| $(playerWithAssist : EntityId)
      playersWithAssist |> push(playerWithAssist)

    createEntity(killTemplate) <| $(var init)
      init |> set("nexus_history__offender", offenderPlr)
      init |> set("nexus_history__victim", possessedByPlr)
      init |> set("nexus_history__at", get_sync_time())
      init |> set("nexus_history__assists", playersWithAssist)
      if longshotKill
        init |> set("nexus_history__killDistance", sqrt(killDistanceSq))


[es(tag=server, REQUIRE=(nexus_history_kill, nexus_history_active), REQUIRE_NOT=(nexus_history_kill_suicide, nexus_history_kill_teamkill), on_appear)]
def nexus_history_kill_group_create(evt : Event;
                                    eid aka history_eid : EntityId;
                                    nexus_history__offender aka new_nexus_history__offender : EntityId;
                                    nexus_history__at : float;
                                    var nexus_history__killGroupEid : EntityId&)
  var mostRecentKillEid = INVALID_ENTITY_ID
  var mostRecentKillTime = 0.0
  var mostRecentKillGroupEid = INVALID_ENTITY_ID
  var groupKillTime = -1.0
  find_query() <| $ [es] (nexus_stats_rules__groupKillTime : float)
    groupKillTime = nexus_stats_rules__groupKillTime
    return true

  query() <| $ [es(REQUIRE=(nexus_history_kill, nexus_history_active), REQUIRE_NOT=(nexus_history_kill_suicide, nexus_history_kill_teamkill))] (eid : EntityId;
                                                                                                                                                nexus_history__offender : EntityId;
                                                                                                                                                nexus_history__at : float;
                                                                                                                                                nexus_history__killGroupEid : EntityId = INVALID_ENTITY_ID)
    if history_eid == eid || new_nexus_history__offender != nexus_history__offender
      return
    if mostRecentKillTime < nexus_history__at
      mostRecentKillEid = eid
      mostRecentKillTime = nexus_history__at
      mostRecentKillGroupEid = nexus_history__killGroupEid

  if (nexus_history__at - mostRecentKillTime) > groupKillTime
    return

  if mostRecentKillGroupEid == INVALID_ENTITY_ID
    using() <| $(var killEntries : EidList)
      killEntries |> resize(2)
      killEntries[0] = mostRecentKillEid
      killEntries[1] = history_eid
      let groupEid = createEntity("nexus_history_kill_group") <| $(var init)
        init |> set("nexus_history__offender", nexus_history__offender)
        init |> set("nexus_history_kill_group__killEntries", killEntries)
      nexus_history__killGroupEid = groupEid
      query(mostRecentKillEid) <| $ [es] (var nexus_history__killGroupEid : EntityId&)
        nexus_history__killGroupEid = groupEid
  else
    nexus_history__killGroupEid = mostRecentKillGroupEid
    query(mostRecentKillGroupEid) <| $ [es] (var nexus_history_kill_group__killEntries : EidList)
      nexus_history_kill_group__killEntries |> push(history_eid)


[es(tag=server, track=nexus_history_kill_group__killEntries)]
def nexus_history_kill_group_track(evt : Event;
                                   nexus_history__offender : EntityId;
                                   nexus_history_kill_group__killEntries : EidList;
                                   var nexus_history_kill_group__previousKillCount : int&)
  let killCount = length(nexus_history_kill_group__killEntries)
  broadcastEvent(EventNexusKillGroupStatChange(playerEid = nexus_history__offender, count = killCount, prevCount = nexus_history_kill_group__previousKillCount))
  nexus_history_kill_group__previousKillCount = killCount
