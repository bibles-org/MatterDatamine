require ecs
require game.events.events_game
require game.events.events_active_matter
require active_matter.game.es.endgame_common
require active_matter.game.es.game_end_reasons_common
require game.es.human_self_resurrection_device_common


[es(tag=server, after=extraction_hero_extracted_server)]
def raid_player_extracted(evt : CmdExtractFromBattlefieldServer;
                          eid : EntityId;
                          team : int)
  if evt.isDebug
    return
  player_finish_raid(eid, team, true)
  assume canSpectate = is_any_teammate_playing(eid, team)
  send_player_endgame_result(team, eid, canSpectate, int(GameEndReasons.YOU_EXTRACTED), /*auto exit*/ !canSpectate)


[es(tag=server, after=damage_model_hp_death_es, REQUIRE_NOT=nexus_militant)]
def raid_player_killed(evt : EventEntityDied; possessedByPlr : EntityId; team : int)
  let hasResurrectCheat = find_query() <| $ [es] (save_point__playerEid : EntityId)
    return possessedByPlr == save_point__playerEid
  if hasResurrectCheat
    return

  let playerResDevice = find_player_ressurection_device(possessedByPlr)
  let canContinue = is_any_teammate_playing(possessedByPlr, team)

  if playerResDevice != INVALID_ENTITY_ID
    send_player_endgame_result(team, possessedByPlr, canContinue, int(GameEndReasons.YOU_DIED), /*auto exit*/ false)
    return

  if !canContinue
    player_finish_raid(possessedByPlr, team, false)

  send_player_endgame_result(team, possessedByPlr, canContinue, int(GameEndReasons.YOU_DIED), /*auto exit*/ !canContinue)


[es(tag=server, on_event=EventTeammateFinishedRaid)]
def raid_on_teammate_finished(evt : Event;
                              eid : EntityId;
                              possessed : EntityId;
                              team : int;
                              scoring_player__isExtractedSuccess : bool)
  var isHeroAlive = false
  query(possessed) <| $ [es] (isAlive : bool)
    isHeroAlive = isAlive
  if isHeroAlive
    return

  if is_any_teammate_playing(eid, team)
    return

  player_finish_raid(eid, team, false)
  assume reason = int(scoring_player__isExtractedSuccess ? GameEndReasons.YOU_EXTRACTED : GameEndReasons.YOU_DIED)
  send_player_endgame_result(team, eid, false, reason, /*auto exit*/ true)


[es(tag=server, on_event=EventResurrectionDeviceExpired)]
def raid_on_resurrection_device_expired(evt : Event; eid aka player_eid : EntityId; team : int)
  let canContinue = is_any_teammate_playing(player_eid, team)
  if !canContinue
    player_finish_raid(player_eid, team, false)

  send_player_endgame_result(team, player_eid, canContinue, int(GameEndReasons.YOU_DIED), /*auto exit*/ !canContinue)


[es(tag=server, on_event=EventSessionFinished, REQUIRE_NOT=nexus_player, REQUIRE=player)]
def raid_save_player_data_on_session_finished(evt : Event; eid : EntityId; team : int)
  player_finish_raid(eid, team, false)
