module nexus_game_end_common shared
require app
require ecs
require ecs.enum_macro
require rapidjson
require jsonwriter
require DagorBase64
require DngNet
require game.es.message_queue_common
require game.es.nexus_common
require game.es.endgame_common
require active_matter.game.es.objectives.objective_common


[export_enum]
enum NexusGameEndState
  None
  GameEnded
  Debriefing
  ClientsLeave
  SessionEnded


struct NexusGameResult
  sessionId : string
  battleAreaInfo : BattleAreaInfo
  isWinner : bool
  credits : int
  team : int
  gameDuration : float
  battleStats : table<string; float>;
  dateTime : string
  players : string
  mvps : string
  mode : string
  modeSpecificData : string
  contractsProgression : array<ContractProgression>
  debriefingStats : table<string; int>


def get_player_nexus_result_data(player_eid : EntityId;
                                 player_team : int;
                                 winner_team : int;
                                 game_duration : float)
  var result : NexusGameResult
  result.sessionId = string(get_session_id())
  result.battleAreaInfo <- get_battle_area_info()
  result.dateTime = string(json_get_or(get_matching_invite_data(), "startTimestamp", 1000ul))
  result.mode = get_nexus_mode()
  result.isWinner = player_team == winner_team
  result.team = player_team
  result.gameDuration = game_duration
  result.contractsProgression <- get_objectives_for_save(true, player_eid)
  result.debriefingStats <- get_debriefing_stats(player_eid)

  jw_writer() <| $(var playerData : JsonWriter)
    playerData |> jw_start_obj()
    query() <| $ [es(REQUIRE=nexus_stats_total)] (nexus_stats__owner : EntityId;
                                                  nexus_stats__kills : int;
                                                  nexus_stats__doubleKills : int;
                                                  nexus_stats__tripleKills : int;
                                                  nexus_stats__multipleKills : int;
                                                  nexus_stats__teamKills : int;
                                                  nexus_stats__meleeKills : int;
                                                  nexus_stats__grenadeKills : int;
                                                  nexus_stats__longshotKills : int;
                                                  nexus_stats__headshotKills : int;
                                                  nexus_stats__hits : int;
                                                  nexus_stats__assists : int;
                                                  nexus_stats__beaconCaptures : int;
                                                  nexus_stats__beaconResets : int;
                                                  nexus_stats__deaths : int;
                                                  nexus_stats__score : int;
                                                  nexus_stats__credits : int)
      if nexus_stats__owner == player_eid
        result.credits = nexus_stats__credits
        var statsToSafe : table<string; float>
        statsToSafe |> insert("kills", float(nexus_stats__kills))
        statsToSafe |> insert("beacon_captures", float(nexus_stats__beaconCaptures))
        statsToSafe |> insert("deaths", float(nexus_stats__deaths))
        statsToSafe |> insert("score", float(nexus_stats__score))
        statsToSafe |> insert("credits", float(nexus_stats__credits))
        result.battleStats <- statsToSafe

      query(nexus_stats__owner) <| $ [es] (eid : EntityId;
                                           userid : uint64;
                                           name : string;
                                           team : int;
                                           playerIsBot : Tag const?)
        playerData |> jw_key_obj("{eid}") <| $()
          if playerIsBot == null
            playerData |> jw_key_value("userId", userid)
          playerData |> jw_key_value("name", name)
          playerData |> jw_key_value("team", team)
          playerData |> jw_key_obj("stats") <| $()
            playerData |> jw_key_value("kill", nexus_stats__kills)
            playerData |> jw_key_value("double_kill", nexus_stats__doubleKills)
            playerData |> jw_key_value("triple_kill", nexus_stats__tripleKills)
            playerData |> jw_key_value("multiple_kill", nexus_stats__multipleKills)
            playerData |> jw_key_value("team_kill", nexus_stats__teamKills)
            playerData |> jw_key_value("melee_kill", nexus_stats__meleeKills)
            playerData |> jw_key_value("grenade_kill", nexus_stats__grenadeKills)
            playerData |> jw_key_value("longshot_kill", nexus_stats__longshotKills)
            playerData |> jw_key_value("headshot_kill", nexus_stats__headshotKills)
            playerData |> jw_key_value("hit", nexus_stats__hits)
            playerData |> jw_key_value("assist", nexus_stats__assists)
            playerData |> jw_key_value("beacon_capture", nexus_stats__beaconCaptures)
            playerData |> jw_key_value("beacon_reset", nexus_stats__beaconResets)
            playerData |> jw_key_value("death", nexus_stats__deaths)
            playerData |> jw_key_value("score", nexus_stats__score)
            playerData |> jw_key_value("credits", nexus_stats__credits)

    playerData |> jw_end_obj()
    result.players = encode_base64(playerData.result)

  jw_writer() <| $(var mvpsData : JsonWriter)
    mvpsData |> jw_start_obj()
    query() <| $ [es(REQUIRE=nexus_mvp_total)] (nexus_mvp__owner : EntityId;
                                                nexus_mvp__team : int;
                                                nexus_mvp__reason : int;
                                                nexus_mvp__score : int)
      if nexus_mvp__owner == INVALID_ENTITY_ID || nexus_mvp__team != player_team
        return
      mvpsData |> jw_key_obj(string(nexus_mvp__reason)) <| $()
        mvpsData |> jw_key_value("owner", "{nexus_mvp__owner}")
        mvpsData |> jw_key_value("score", nexus_mvp__score)
    mvpsData |> jw_end_obj()
    result.mvps = encode_base64(mvpsData.result)

  if (result.mode == "round")
    var score : table <int; int>
    query() <| $ [es(REQUIRE=nexus_team)] (team__id : int;
                                           nexus_round_mode_team__wonRounds : int)
      score |> insert(team__id, nexus_round_mode_team__wonRounds)

    jw_writer() <| $(var roundModeData : JsonWriter)
      roundModeData |> jw_start_obj()
      roundModeData |> jw_key_obj("score") <| $()
        for teamId, teamScore in keys(score), values(score)
          roundModeData |> jw_key_value("{teamId}", teamScore)
      roundModeData |> jw_end_obj()
      result.modeSpecificData = encode_base64(roundModeData.result)

  return <- result
