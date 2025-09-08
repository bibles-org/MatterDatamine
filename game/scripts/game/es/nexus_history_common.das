module nexus_history_common shared
require ecs
require player


let ASSIST_MAX_TIME = 10.0
let ASSIST_DAMAGE_THRESHOLD = 10.0


def query_players_with_hits(victim_player : EntityId;
                            killer_player : EntityId;
                            victim_team : int;
                            cb : block<(eid : EntityId) : void>)
  var playersWithHits : table<EntityId>
  query() <| $ [es(REQUIRE=(nexus_history_active, nexus_history_hit))] (nexus_history__offender : EntityId;
                                                                        nexus_history__victim : EntityId)
    if nexus_history__victim != victim_player || nexus_history__offender == killer_player || key_exists(playersWithHits, nexus_history__offender)
      return
    var hitOffenderTeam = TEAM_UNASSIGNED
    query(nexus_history__offender) <| $ [es] (team : int)
      hitOffenderTeam = team
    if hitOffenderTeam == victim_team
      return

    playersWithHits |> insert(nexus_history__offender)
    invoke(cb, nexus_history__offender)


def query_players_with_assist(victim_player : EntityId;
                              killer_player : EntityId;
                              victim_team : int;
                              kill_time : float;
                              cb : block<(eid : EntityId) : void>)
  var assistsDamage : table<EntityId; float>
  var assistsMostRecentTime : table<EntityId; float>
  query() <| $ [es(REQUIRE=(nexus_history_active, nexus_history_hit))] (nexus_history__offender : EntityId;
                                                                        nexus_history__victim : EntityId;
                                                                        nexus_history__damage : float;
                                                                        nexus_history__at : float)
    if nexus_history__victim != victim_player || nexus_history__offender == killer_player
      return
    var hitOffenderTeam = TEAM_UNASSIGNED
    query(nexus_history__offender) <| $ [es] (team : int)
      hitOffenderTeam = team
    if hitOffenderTeam == victim_team
      return

    if key_exists(assistsDamage, nexus_history__offender)
      assistsDamage |> get(nexus_history__offender) <| $(var damage)
        damage += nexus_history__damage
    else
      assistsDamage |> insert(nexus_history__offender, nexus_history__damage)

    if key_exists(assistsMostRecentTime, nexus_history__offender)
      assistsMostRecentTime |> get(nexus_history__offender) <| $(var time)
        if time < nexus_history__at
          time = nexus_history__at
    else
      assistsMostRecentTime |> insert(nexus_history__offender, nexus_history__at)

  var assistsToErase : table<EntityId>
  for assistPlayer, assistDamage in keys(assistsDamage), values(assistsDamage)
    if assistDamage < ASSIST_DAMAGE_THRESHOLD
      assistsToErase |> insert(assistPlayer)

  for assistToErase in keys(assistsToErase)
    assistsDamage |> erase(assistToErase)
    assistsMostRecentTime |> erase(assistToErase)

  var mostRecentAssistPlayer = INVALID_ENTITY_ID
  var mostRecentAssistTime = -1.0
  for assistPlayer, assistMostRecentTime in keys(assistsMostRecentTime), values(assistsMostRecentTime)
    if mostRecentAssistTime < assistMostRecentTime
      mostRecentAssistPlayer = assistPlayer
      mostRecentAssistTime = assistMostRecentTime

  if mostRecentAssistPlayer == INVALID_ENTITY_ID || kill_time - mostRecentAssistTime > ASSIST_MAX_TIME
    return
  invoke(cb, mostRecentAssistPlayer)
