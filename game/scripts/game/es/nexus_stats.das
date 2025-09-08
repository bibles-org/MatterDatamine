require ecs
require ecs.safe
require player
require DngNet
require game.events.events_active_matter
require game.es.nexus_stats_common
require game.es.nexus_round_mode_common
require game.es.nexus_common

def nexus_get_stat_data(stat : int;
                        scoresheet : Object)
  if stat == int(NexusStatType.KILL)
    return scoresheet.kill ?as Object
  elif stat == int(NexusStatType.ASSIST)
    return scoresheet.assist ?as Object
  elif stat == int(NexusStatType.HIT)
    return scoresheet.hit ?as Object
  elif stat == int(NexusStatType.GRENADE_KILL)
    return scoresheet.grenade_kill ?as Object
  elif stat == int(NexusStatType.MELEE_KILL)
    return scoresheet.melee_kill ?as Object
  elif stat == int(NexusStatType.HEADSHOT_KILL)
    return scoresheet.headshot_kill ?as Object
  elif stat == int(NexusStatType.TEAM_KILL)
    return scoresheet.team_kill ?as Object
  elif stat == int(NexusStatType.LONGSHOT_KILL)
    return scoresheet.longshot_kill ?as Object
  elif stat == int(NexusStatType.BEACON_CAPTURE)
    return scoresheet.beacon_capture ?as Object
  elif stat == int(NexusStatType.BEACON_RESET)
    return scoresheet.beacon_reset ?as Object
  elif stat == int(NexusStatType.DEATH)
    return scoresheet.death ?as Object
  return scoresheet.undefined ?as Object


def nexus_get_stat_all(stat : int;
                       scoresheet : Object)
  let statData = nexus_get_stat_data(stat, scoresheet)
  return (statData.score ?? 0, statData.credits ?? 0)


def nexus_get_stat_all(stat : int)
  var score = 0
  var credits = 0
  find_query() <| $ [es] (nexus_stats__scoresheet : Object)
    let (statScore, statCredits) = nexus_get_stat_all(stat, nexus_stats__scoresheet)
    score = statScore
    credits = statCredits
    return true
  return (score, credits)


def nexus_get_stats_all(stats : IntList)
  var score = 0
  var credits = 0
  find_query() <| $ [es] (nexus_stats__scoresheet : Object)
    for stat in stats
      let (statScore, statCredits) = nexus_get_stat_all(stat, nexus_stats__scoresheet)
      score += statScore
      credits += statCredits
    return true
  return (score, credits)


def nexus_get_stat_score(stat : int;
                         scoresheet : Object)
  let statData = nexus_get_stat_data(stat, scoresheet)
  return statData.score ?? 0


def nexus_get_stat_credits(stat : int;
                           scoresheet : Object)
  let statData = nexus_get_stat_data(stat, scoresheet)
  return statData.credits ?? 0


def nexus_get_group_kill_data(kill_count : int;
                              scoresheet : Object)
  if kill_count == 2
    return scoresheet.double_kill ?as Object
  elif kill_count == 3
    return scoresheet.triple_kill ?as Object
  elif kill_count >= 4
    return scoresheet.multiple_kill ?as Object
  return scoresheet.undefined ?as Object


def nexus_get_group_kill_all(kill_count : int;
                             scoresheet : Object)
  let groupKillData = nexus_get_group_kill_data(kill_count, scoresheet)
  return (groupKillData.score ?? 0, groupKillData.credits ?? 0)


def nexus_get_group_kill_all(kill_count : int)
  var score = 0
  var credits = 0
  find_query() <| $ [es] (nexus_stats__scoresheet : Object)
    let (groupKillScore, groupKillCredits) = nexus_get_group_kill_all(kill_count, nexus_stats__scoresheet)
    score = groupKillScore
    credits = groupKillCredits
    return true
  return (score, credits)


def nexus_combine_kill_stats(suicide : bool;
                             teamkill : bool;
                             grenade : bool;
                             melee : bool;
                             longshot : bool;
                             headshot : bool;
                             var stats : IntList&)
  if suicide
    return
  if teamkill
    stats |> push(int(NexusStatType.TEAM_KILL))
    return
  stats |> push(int(NexusStatType.KILL))

  if melee
    stats |> push(int(NexusStatType.MELEE_KILL))
    return
  if longshot
    stats |> push(int(NexusStatType.LONGSHOT_KILL))
    if grenade
      stats |> push(int(NexusStatType.GRENADE_KILL))
      return
    if headshot
      stats |> push(int(NexusStatType.HEADSHOT_KILL))
      return
  if grenade
    stats |> push(int(NexusStatType.GRENADE_KILL))
    return
  if headshot
    stats |> push(int(NexusStatType.HEADSHOT_KILL))
    return


def nexus_change_group_kills(count : int;
                             previous_count : int;
                             var nexus_stats__doubleKills : int&;
                             var nexus_stats__tripleKills : int&;
                             var nexus_stats__multipleKills : int&;
                             var nexus_stats__score : int&;
                             var nexus_stats__credits : int&)


  find_query() <| $ [es] (nexus_stats__scoresheet : Object)
    if previous_count == 2
      --nexus_stats__doubleKills
      let (score, credits) = nexus_get_group_kill_all(2, nexus_stats__scoresheet)
      nexus_stats__score -= score
      nexus_stats__credits -= credits
    elif previous_count == 3
      --nexus_stats__tripleKills
      let (score, credits) = nexus_get_group_kill_all(3, nexus_stats__scoresheet)
      nexus_stats__score -= score
      nexus_stats__credits -= credits

    if count == 2
      ++nexus_stats__doubleKills
      let (score, credits) = nexus_get_group_kill_all(2, nexus_stats__scoresheet)
      nexus_stats__score += score
      nexus_stats__credits += credits
    elif count == 3
      ++nexus_stats__tripleKills
      let (score, credits) = nexus_get_group_kill_all(3, nexus_stats__scoresheet)
      nexus_stats__score += score
      nexus_stats__credits += credits
    elif count >= 4 && previous_count < 4
      ++nexus_stats__multipleKills
      let (score, credits) = nexus_get_group_kill_all(4, nexus_stats__scoresheet)
      nexus_stats__score += score
      nexus_stats__credits += credits
    return true


def nexus_increase_kills(stats : IntList;
                         var nexus_stats__kills : int&;
                         var nexus_stats__teamKills : int&;
                         var nexus_stats__meleeKills : int&;
                         var nexus_stats__grenadeKills : int&;
                         var nexus_stats__longshotKills : int&;
                         var nexus_stats__headshotKills : int&)
  for stat in stats
    if stat == int(NexusStatType.KILL)
      ++nexus_stats__kills
    elif stat == int(NexusStatType.GRENADE_KILL)
      ++nexus_stats__grenadeKills
    elif stat == int(NexusStatType.MELEE_KILL)
      ++nexus_stats__meleeKills
    elif stat == int(NexusStatType.HEADSHOT_KILL)
      ++nexus_stats__headshotKills
    elif stat == int(NexusStatType.TEAM_KILL)
      ++nexus_stats__teamKills
    elif stat == int(NexusStatType.LONGSHOT_KILL)
      ++nexus_stats__longshotKills


def try_get_mvp_for_most_kills(nexus_stats_eid : EntityId;
                               player_eid : EntityId;
                               kills : int;
                               total_score : int;
                               var nexus_mvp__owner : EntityId&;
                               var nexus_mvp__stats : EntityId&;
                               var nexus_mvp__score : int&)
  find_query() <| $ [es] (nexus_stats__scoresheet : Object)
    let score = kills * nexus_get_stat_score(int(NexusStatType.KILL), nexus_stats__scoresheet)
    if score > nexus_mvp__score
      nexus_mvp__owner = player_eid
      nexus_mvp__stats = nexus_stats_eid
      nexus_mvp__score = score
    elif score == nexus_mvp__score && player_eid != nexus_mvp__owner
      query(nexus_mvp__stats) <| $ [es] (nexus_stats__score : int)
        if total_score > nexus_stats__score
          nexus_mvp__owner = player_eid
          nexus_mvp__stats = nexus_stats_eid
    return true


def try_get_mvp_for_most_help(nexus_stats_eid : EntityId;
                              player_eid : EntityId;
                              assists : int;
                              beacon_resets : int;
                              total_score : int;
                              var nexus_mvp__owner : EntityId&;
                              var nexus_mvp__stats : EntityId&;
                              var nexus_mvp__score : int&)
  find_query() <| $ [es] (nexus_stats__scoresheet : Object)
    let score = assists * nexus_get_stat_score(int(NexusStatType.ASSIST), nexus_stats__scoresheet) + beacon_resets * nexus_get_stat_score(int(NexusStatType.BEACON_RESET), nexus_stats__scoresheet)
    if score > nexus_mvp__score
      nexus_mvp__owner = player_eid
      nexus_mvp__stats = nexus_stats_eid
      nexus_mvp__score = score
    elif score == nexus_mvp__score && player_eid != nexus_mvp__owner
      query(nexus_mvp__stats) <| $ [es] (nexus_stats__score : int)
        if total_score > nexus_stats__score
          nexus_mvp__owner = player_eid
          nexus_mvp__stats = nexus_stats_eid
    return true


def try_get_mvp_for_most_beacon_captures(nexus_stats_eid : EntityId;
                                         player_eid : EntityId;
                                         beacon_captures : int;
                                         total_score : int;
                                         var nexus_mvp__owner : EntityId&;
                                         var nexus_mvp__stats : EntityId&;
                                         var nexus_mvp__score : int&)
  find_query() <| $ [es] (nexus_stats__scoresheet : Object)
    let score = beacon_captures * nexus_get_stat_score(int(NexusStatType.BEACON_CAPTURE), nexus_stats__scoresheet)
    if score > nexus_mvp__score
      nexus_mvp__owner = player_eid
      nexus_mvp__stats = nexus_stats_eid
      nexus_mvp__score = score
    elif score == nexus_mvp__score && player_eid != nexus_mvp__owner
      query(nexus_mvp__stats) <| $ [es] (nexus_stats__score : int)
        if total_score > nexus_stats__score
          nexus_mvp__owner = player_eid
          nexus_mvp__stats = nexus_stats_eid
    return true


def create_nexus_stats_total(player_eid : EntityId;
                             team : int)
  createEntity("nexus_stats+nexus_stats_total") <| $(var init)
    init |> set("nexus_stats__owner", player_eid)
    init |> set("nexus_stats__team", team)


def create_nexus_stats_round(player_eid : EntityId;
                             round_number : int;
                             team : int)
  createEntity("nexus_stats+nexus_stats_round+nexus_stats_current_round") <| $(var init)
    init |> set("nexus_stats__owner", player_eid)
    init |> set("nexus_stats__round", round_number)
    init |> set("nexus_stats__team", team)


[es(tag=server, on_appear)]
def nexus_stats_rules_init(evt : Event;
                           nexus_stats_rules__longshotKillDistance : float;
                           var nexus_stats_rules__longshotKillDistanceSq : float&)
  nexus_stats_rules__longshotKillDistanceSq = nexus_stats_rules__longshotKillDistance * nexus_stats_rules__longshotKillDistance


[es(tag=server, REQUIRE=nexus_player)]
def nexus_stats_total_init(evt : EventNexusGameStart;
                           eid aka player_eid : EntityId;
                           team : int)
  create_nexus_stats_total(player_eid, team)


[es(tag=server, REQUIRE=nexus_player, on_appear)]
def nexus_stats_total_init_on_player_appear(evt : Event;
                                            eid aka player_eid : EntityId;
                                            team : int)
  let statsAlreadyExists = find_query() <| $ [es(REQUIRE=nexus_stats_total)] (nexus_stats__owner : EntityId) => nexus_stats__owner == player_eid
  if statsAlreadyExists || !is_game_started()
    return
  create_nexus_stats_total(player_eid, team)


[es(tag=gameClient, REQUIRE_NOT=nexus_stats_local, on_appear)]
def nexus_stats_local_init(evt : Event;
                           eid : EntityId;
                           nexus_stats__owner : EntityId)
  if nexus_stats__owner != get_local_player_eid()
    return
  addSubTemplate(eid, "nexus_stats_local")


[es(tag=server, REQUIRE=(nexus_player, nexus_round_mode), on_event=(EventNexusGameStart, EventNexusRoundModeRoundChange))]
def nexus_stats_round_init(evt : Event;
                           eid aka player_eid : EntityId;
                           team : int)
  let nexusRoundNumber = get_round_number()
  create_nexus_stats_round(player_eid, nexusRoundNumber, team)


[es(tag=server, REQUIRE=nexus_player, on_appear)]
def nexus_stats_round_init_on_player_appear(evt : Event;
                                            eid aka player_eid : EntityId;
                                            team : int)
  let nexusRoundNumber = get_round_number()
  let statsAlreadyExists = find_query() <| $ [es] (nexus_stats__owner : EntityId;
                                                   nexus_stats__round : int)
    return nexus_stats__owner == player_eid && nexus_stats__round == nexusRoundNumber
  if statsAlreadyExists || !is_game_started()
    return
  create_nexus_stats_round(player_eid, nexusRoundNumber, team)


[es(tag=server, REQUIRE=nexus_stats_current_round, on_event=(EventNexusRoundModeRoundChange))]
def nexus_stats_current_round_reset(evt : Event;
                                    eid : EntityId)
  remote_remove_sub_template(eid, "nexus_stats_current_round")


[es(tag=server, REQUIRE=nexus_mvp_current_round, on_event=(EventNexusRoundModeRoundChange))]
def nexus_mvp_current_round_reset(evt : Event;
                                  eid : EntityId)
  remote_remove_sub_template(eid, "nexus_mvp_current_round")


[es(tag=server, REQUIRE=(nexus_history_kill), on_appear)]
def nexus_stats_track_kills(evt : Event;
                            nexus_history__victim : EntityId;
                            nexus_history__offender : EntityId;
                            nexus_history__assists : EidList;
                            nexus_history_kill_suicide : Tag const?;
                            nexus_history_kill_teamkill : Tag const?;
                            nexus_history_kill_grenade : Tag const?;
                            nexus_history_kill_melee : Tag const?;
                            nexus_history_kill_longshot : Tag const?;
                            nexus_history_kill_headshot : Tag const?)
  broadcastEvent(EventNexusDeathStatIncrease(playerEid = nexus_history__victim))
  for playerWithAssist in nexus_history__assists
    broadcastEvent(EventNexusAssistStatIncrease(playerEid = playerWithAssist))

  using() <| $(var stats : IntList)
    nexus_combine_kill_stats(nexus_history_kill_suicide != null, nexus_history_kill_teamkill != null, nexus_history_kill_grenade != null,
                             nexus_history_kill_melee != null, nexus_history_kill_longshot != null, nexus_history_kill_headshot != null,
                             stats)
    if empty(stats)
      return
    broadcastEvent(EventNexusKillStatIncrease(playerEid = nexus_history__offender, stats = ecs_addr(stats)))


[es(tag=server, REQUIRE=(nexus_history_hit, nexus_history_active), REQUIRE_NOT=(nexus_history_hit_team, nexus_history_hit_self), on_appear)]
def nexus_stats_track_hits(evt : Event;
                           nexus_history__offender : EntityId)
  broadcastEvent(EventNexusHitStatIncrease(playerEid = nexus_history__offender))


[es(tag=server, REQUIRE=(nexus_history_beacon_capture), on_appear)]
def nexus_stats_track_beacon_captures(evt : Event;
                                      nexus_history__participants : EidList)
  for participant in nexus_history__participants
    broadcastEvent(EventNexusBeaconCaptureStatIncrease(playerEid = participant))


[es(tag=server, REQUIRE=(nexus_history_beacon_reset), on_appear)]
def nexus_stats_track_beacon_resets(evt : Event;
                                    nexus_history__participants : EidList)
  for participant in nexus_history__participants
    broadcastEvent(EventNexusBeaconResetStatIncrease(playerEid = participant))


[es(tag=server, REQUIRE=nexus_stats_total)]
def nexus_stats_total_change_group_kills(evt : EventNexusKillGroupStatChange;
                                         nexus_stats__owner : EntityId;
                                         var nexus_stats__doubleKills : int&;
                                         var nexus_stats__tripleKills : int&;
                                         var nexus_stats__multipleKills : int&;
                                         var nexus_stats__score : int&;
                                         var nexus_stats__credits : int&)
  if nexus_stats__owner != evt.playerEid
    return
  nexus_change_group_kills(evt.count, evt.prevCount, nexus_stats__doubleKills, nexus_stats__tripleKills, nexus_stats__multipleKills, nexus_stats__score, nexus_stats__credits)


[es(tag=server, REQUIRE=nexus_stats_current_round)]
def nexus_stats_current_round_change_group_kills(evt : EventNexusKillGroupStatChange;
                                                 nexus_stats__owner : EntityId;
                                                 var nexus_stats__doubleKills : int&;
                                                 var nexus_stats__tripleKills : int&;
                                                 var nexus_stats__multipleKills : int&;
                                                 var nexus_stats__score : int&;
                                                 var nexus_stats__credits : int&)
  if nexus_stats__owner != evt.playerEid
    return
  nexus_change_group_kills(evt.count, evt.prevCount, nexus_stats__doubleKills, nexus_stats__tripleKills, nexus_stats__multipleKills, nexus_stats__score, nexus_stats__credits)


[es(tag=server, REQUIRE=nexus_stats_total)]
def nexus_stats_total_increase_kills(evt : EventNexusKillStatIncrease;
                                     nexus_stats__owner : EntityId;
                                     var nexus_stats__kills : int&;
                                     var nexus_stats__teamKills : int&;
                                     var nexus_stats__meleeKills : int&;
                                     var nexus_stats__grenadeKills : int&;
                                     var nexus_stats__longshotKills : int&;
                                     var nexus_stats__headshotKills : int&;
                                     var nexus_stats__score : int&;
                                     var nexus_stats__credits : int&)
  if nexus_stats__owner != evt.playerEid
    return
  nexus_increase_kills((*evt.stats), nexus_stats__kills, nexus_stats__teamKills, nexus_stats__meleeKills, nexus_stats__grenadeKills, nexus_stats__longshotKills, nexus_stats__headshotKills)
  let (score, credits) = nexus_get_stats_all(*evt.stats)
  nexus_stats__score += score
  nexus_stats__credits += credits


[es(tag=server, REQUIRE=nexus_stats_current_round)]
def nexus_stats_current_round_increase_kills(evt : EventNexusKillStatIncrease;
                                             nexus_stats__owner : EntityId;
                                             var nexus_stats__kills : int&;
                                             var nexus_stats__teamKills : int&;
                                             var nexus_stats__meleeKills : int&;
                                             var nexus_stats__grenadeKills : int&;
                                             var nexus_stats__longshotKills : int&;
                                             var nexus_stats__headshotKills : int&;
                                             var nexus_stats__score : int&;
                                             var nexus_stats__credits : int&)
  if nexus_stats__owner != evt.playerEid
    return
  nexus_increase_kills((*evt.stats), nexus_stats__kills, nexus_stats__teamKills, nexus_stats__meleeKills, nexus_stats__grenadeKills, nexus_stats__longshotKills, nexus_stats__headshotKills)
  let (score, credits) = nexus_get_stats_all(*evt.stats)
  nexus_stats__score += score
  nexus_stats__credits += credits


[es(tag=server, REQUIRE=nexus_stats_total)]
def nexus_stats_total_increase_assists(evt : EventNexusAssistStatIncrease;
                                       nexus_stats__owner : EntityId;
                                       var nexus_stats__assists : int&;
                                       var nexus_stats__score : int&;
                                       var nexus_stats__credits : int&)
  if nexus_stats__owner != evt.playerEid
    return
  ++nexus_stats__assists
  let (score, credits) = nexus_get_stat_all(int(NexusStatType.ASSIST))
  nexus_stats__score += score
  nexus_stats__credits += credits


[es(tag=server, REQUIRE=nexus_stats_current_round)]
def nexus_stats_current_round_increase_assists(evt : EventNexusAssistStatIncrease;
                                               nexus_stats__owner : EntityId;
                                               var nexus_stats__assists : int&;
                                               var nexus_stats__score : int&;
                                               var nexus_stats__credits : int&)
  if nexus_stats__owner != evt.playerEid
    return
  ++nexus_stats__assists
  let (score, credits) = nexus_get_stat_all(int(NexusStatType.ASSIST))
  nexus_stats__score += score
  nexus_stats__credits += credits


[es(tag=server, REQUIRE=nexus_stats_total)]
def nexus_stats_total_increase_hits(evt : EventNexusHitStatIncrease;
                                    nexus_stats__owner : EntityId;
                                    var nexus_stats__hits : int&;
                                    var nexus_stats__score : int&;
                                    var nexus_stats__credits : int&)
  if nexus_stats__owner != evt.playerEid
    return
  ++nexus_stats__hits
  let (score, credits) = nexus_get_stat_all(int(NexusStatType.HIT))
  nexus_stats__score += score
  nexus_stats__credits += credits


[es(tag=server, REQUIRE=nexus_stats_current_round)]
def nexus_stats_current_round_increase_hits(evt : EventNexusHitStatIncrease;
                                            nexus_stats__owner : EntityId;
                                            var nexus_stats__hits : int&;
                                            var nexus_stats__score : int&;
                                            var nexus_stats__credits : int&)
  if nexus_stats__owner != evt.playerEid
    return
  ++nexus_stats__hits
  let (score, credits) = nexus_get_stat_all(int(NexusStatType.HIT))
  nexus_stats__score += score
  nexus_stats__credits += credits


[es(tag=server, REQUIRE=nexus_stats_total)]
def nexus_stats_total_increase_beacon_captures(evt : EventNexusBeaconCaptureStatIncrease;
                                               nexus_stats__owner : EntityId;
                                               var nexus_stats__beaconCaptures : int&;
                                               var nexus_stats__score : int&;
                                               var nexus_stats__credits : int&)
  if nexus_stats__owner != evt.playerEid
    return
  ++nexus_stats__beaconCaptures
  let (score, credits) = nexus_get_stat_all(int(NexusStatType.BEACON_CAPTURE))
  nexus_stats__score += score
  nexus_stats__credits += credits


[es(tag=server, REQUIRE=nexus_stats_current_round)]
def nexus_stats_current_round_increase_beacon_captures(evt : EventNexusBeaconCaptureStatIncrease;
                                                       nexus_stats__owner : EntityId;
                                                       var nexus_stats__beaconCaptures : int&;
                                                       var nexus_stats__score : int&;
                                                       var nexus_stats__credits : int&)
  if nexus_stats__owner != evt.playerEid
    return
  ++nexus_stats__beaconCaptures
  let (score, credits) = nexus_get_stat_all(int(NexusStatType.BEACON_CAPTURE))
  nexus_stats__score += score
  nexus_stats__credits += credits


[es(tag=server, REQUIRE=nexus_stats_total)]
def nexus_stats_total_increase_beacon_resets(evt : EventNexusBeaconResetStatIncrease;
                                             nexus_stats__owner : EntityId;
                                             var nexus_stats__beaconResets : int&;
                                             var nexus_stats__score : int&;
                                             var nexus_stats__credits : int&)
  if nexus_stats__owner != evt.playerEid
    return
  ++nexus_stats__beaconResets
  let (score, credits) = nexus_get_stat_all(int(NexusStatType.BEACON_RESET))
  nexus_stats__score += score
  nexus_stats__credits += credits


[es(tag=server, REQUIRE=nexus_stats_current_round)]
def nexus_stats_current_round_increase_beacon_resets(evt : EventNexusBeaconResetStatIncrease;
                                                     nexus_stats__owner : EntityId;
                                                     var nexus_stats__beaconResets : int&;
                                                     var nexus_stats__score : int&;
                                                     var nexus_stats__credits : int&)
  if nexus_stats__owner != evt.playerEid
    return
  ++nexus_stats__beaconResets
  let (score, credits) = nexus_get_stat_all(int(NexusStatType.BEACON_RESET))
  nexus_stats__score += score
  nexus_stats__credits += credits


[es(tag=server, REQUIRE=nexus_stats_total)]
def nexus_stats_total_increase_deaths(evt : EventNexusDeathStatIncrease;
                                      nexus_stats__owner : EntityId;
                                      var nexus_stats__deaths : int&;
                                      var nexus_stats__score : int&;
                                      var nexus_stats__credits : int&)
  if nexus_stats__owner != evt.playerEid
    return
  ++nexus_stats__deaths
  let (score, credits) = nexus_get_stat_all(int(NexusStatType.DEATH))
  nexus_stats__score += score
  nexus_stats__credits += credits


[es(tag=server, REQUIRE=nexus_stats_current_round)]
def nexus_stats_current_round_increase_deaths(evt : EventNexusDeathStatIncrease;
                                              nexus_stats__owner : EntityId;
                                              var nexus_stats__deaths : int&;
                                              var nexus_stats__score : int&;
                                              var nexus_stats__credits : int&)
  if nexus_stats__owner != evt.playerEid
    return
  ++nexus_stats__deaths
  let (score, credits) = nexus_get_stat_all(int(NexusStatType.DEATH))
  nexus_stats__score += score
  nexus_stats__credits += credits


[es(tag=gameClient, REQUIRE=(nexus_history_offender_local, nexus_history_kill), on_appear)]
def nexus_stats_track_local_kills(evt : Event;
                                  nexus_history__offender : EntityId;
                                  nexus_history__victim : EntityId;
                                  nexus_history_kill_suicide : Tag const?;
                                  nexus_history_kill_teamkill : Tag const?;
                                  nexus_history_kill_grenade : Tag const?;
                                  nexus_history_kill_melee : Tag const?;
                                  nexus_history_kill_longshot : Tag const?;
                                  nexus_history_kill_headshot : Tag const?)
  using() <| $(var stats : IntList)
    nexus_combine_kill_stats(nexus_history_kill_suicide != null, nexus_history_kill_teamkill != null, nexus_history_kill_grenade != null,
                             nexus_history_kill_melee != null, nexus_history_kill_longshot != null, nexus_history_kill_headshot != null,
                             stats)
    if empty(stats)
      return
    let (score, credits) = nexus_get_stats_all(stats)
    sendEvent(nexus_history__offender, EventNexusKillStatChanged(victimEid = nexus_history__victim, stats = ecs_addr(stats), score = score, credits = credits))


[es(tag=gameClient, REQUIRE=(nexus_history_offender_local, nexus_history_kill_group), track=nexus_history_kill_group__killEntries, on_appear)]
def nexus_stats_track_local_kill_groups(evt : Event;
                                        nexus_history__offender : EntityId;
                                        nexus_history_kill_group__killEntries : EidList)
  let killCount = length(nexus_history_kill_group__killEntries)
  if killCount < 2
    return

  let (score, credits) = nexus_get_group_kill_all(killCount)
  sendEvent(nexus_history__offender, EventNexusKillGroupStatChanged(count = killCount, score = score, credits = credits))


[es(tag=gameClient, REQUIRE=(nexus_history_assist_local, nexus_history_kill), on_appear)]
def nexus_stats_track_local_assists(evt : Event;
                                    nexus_history__victim : EntityId)
  let (score, credits) = nexus_get_stat_all(int(NexusStatType.ASSIST))
  sendEvent(get_local_player_eid(), EventNexusAssistStatChanged(victimEid = nexus_history__victim, score = score, credits = credits))


[es(tag=gameClient, REQUIRE=(nexus_history_participant_local, nexus_history_beacon_capture), on_appear)]
def nexus_stats_track_local_beacon_captures(evt : Event)
  let (score, credits) = nexus_get_stat_all(int(NexusStatType.BEACON_CAPTURE))
  sendEvent(get_local_player_eid(), EventNexusSimpleStatChanged(stat = int(NexusStatType.BEACON_CAPTURE), count = 1, score = score, credits = credits))


[es(tag=gameClient, REQUIRE=(nexus_history_participant_local, nexus_history_beacon_reset), on_appear)]
def nexus_stats_track_local_beacon_resets(evt : Event)
  let (score, credits) = nexus_get_stat_all(int(NexusStatType.BEACON_RESET))
  sendEvent(get_local_player_eid(), EventNexusSimpleStatChanged(stat = int(NexusStatType.BEACON_RESET), count = 1, score = score, credits = credits))


[es(tag=server, REQUIRE=nexus_game_controller)]
def nexus_mvp_init_for_game(evt : EventNexusGameStart)
  let mvpReasons = [int(NexusMvpReason.MOST_KILLS), int(NexusMvpReason.MOST_HELP), int(NexusMvpReason.MOST_BEACON_CAPTURES)]
  for mvpReason in mvpReasons
    createEntity("nexus_mvp+nexus_mvp_total") <| $(var init)
      init |> set("nexus_mvp__owner", INVALID_ENTITY_ID)
      init |> set("nexus_mvp__reason", mvpReason)
      init |> set("nexus_mvp__score", 0)

    createEntity("nexus_mvp+nexus_mvp_total+nexus_mvp_team") <| $(var init)
      init |> set("nexus_mvp__owner", INVALID_ENTITY_ID)
      init |> set("nexus_mvp__reason", mvpReason)
      init |> set("nexus_mvp__score", 0)
      init |> set("nexus_mvp__team", int(NexusTeam.FIRST))

    createEntity("nexus_mvp+nexus_mvp_total+nexus_mvp_team") <| $(var init)
      init |> set("nexus_mvp__owner", INVALID_ENTITY_ID)
      init |> set("nexus_mvp__reason", mvpReason)
      init |> set("nexus_mvp__score", 0)
      init |> set("nexus_mvp__team", int(NexusTeam.SECOND))


[es(tag=server, on_event=(EventNexusGameStart, EventNexusRoundModeRoundChange))]
def nexus_mvp_init_for_round(evt : Event;
                             nexus_round_mode_game_controller__roundNumber : int)
  let mvpReasons = [int(NexusMvpReason.MOST_KILLS), int(NexusMvpReason.MOST_HELP), int(NexusMvpReason.MOST_BEACON_CAPTURES)]
  for mvpReason in mvpReasons
    createEntity("nexus_mvp+nexus_mvp_round+nexus_mvp_current_round") <| $(var init)
      init |> set("nexus_mvp__owner", INVALID_ENTITY_ID)
      init |> set("nexus_mvp__reason", mvpReason)
      init |> set("nexus_mvp__score", 0)
      init |> set("nexus_mvp__round", nexus_round_mode_game_controller__roundNumber)

    createEntity("nexus_mvp+nexus_mvp_round+nexus_mvp_current_round+nexus_mvp_team") <| $(var init)
      init |> set("nexus_mvp__owner", INVALID_ENTITY_ID)
      init |> set("nexus_mvp__reason", mvpReason)
      init |> set("nexus_mvp__score", 0)
      init |> set("nexus_mvp__team", int(NexusTeam.FIRST))

    createEntity("nexus_mvp+nexus_mvp_round+nexus_mvp_current_round+nexus_mvp_team") <| $(var init)
      init |> set("nexus_mvp__owner", INVALID_ENTITY_ID)
      init |> set("nexus_mvp__reason", mvpReason)
      init |> set("nexus_mvp__score", 0)
      init |> set("nexus_mvp__team", int(NexusTeam.SECOND))


[es(tag=server, REQUIRE=nexus_stats_total, track=(nexus_stats__kills, nexus_stats__score))]
def nexus_mvp_try_get_most_kills_for_game(evt : Event;
                                          eid : EntityId;
                                          nexus_stats__owner : EntityId;
                                          nexus_stats__team : int;
                                          nexus_stats__kills : int;
                                          nexus_stats__score : int)
  find_query() <| $ [es(REQUIRE=nexus_mvp_total, REQUIRE_NOT=nexus_mvp__team)] (nexus_mvp__reason : int;
                                                                                var nexus_mvp__owner : EntityId&;
                                                                                var nexus_mvp__stats : EntityId&;
                                                                                var nexus_mvp__score : int&)
    if nexus_mvp__reason != int(NexusMvpReason.MOST_KILLS)
      return false
    try_get_mvp_for_most_kills(eid, nexus_stats__owner, nexus_stats__kills, nexus_stats__score, nexus_mvp__owner, nexus_mvp__stats, nexus_mvp__score)
    return true

  find_query() <| $ [es(REQUIRE=nexus_mvp_total)] (nexus_mvp__reason : int;
                                                   nexus_mvp__team : int;
                                                   var nexus_mvp__owner : EntityId&;
                                                   var nexus_mvp__stats : EntityId&;
                                                   var nexus_mvp__score : int&)
    if nexus_mvp__reason != int(NexusMvpReason.MOST_KILLS) || nexus_mvp__team != nexus_stats__team
      return false
    try_get_mvp_for_most_kills(eid, nexus_stats__owner, nexus_stats__kills, nexus_stats__score, nexus_mvp__owner, nexus_mvp__stats, nexus_mvp__score)
    return true


[es(tag=server, REQUIRE=nexus_stats_current_round, track=(nexus_stats__kills, nexus_stats__score))]
def nexus_mvp_try_get_most_kills_for_round(evt : Event;
                                           eid : EntityId;
                                           nexus_stats__owner : EntityId;
                                           nexus_stats__team : int;
                                           nexus_stats__kills : int;
                                           nexus_stats__score : int)
  find_query() <| $ [es(REQUIRE=nexus_mvp_current_round, REQUIRE_NOT=nexus_mvp__team)] (nexus_mvp__reason : int;
                                                                                        var nexus_mvp__owner : EntityId&;
                                                                                        var nexus_mvp__stats : EntityId&;
                                                                                        var nexus_mvp__score : int&)
    if nexus_mvp__reason != int(NexusMvpReason.MOST_KILLS)
      return false
    try_get_mvp_for_most_kills(eid, nexus_stats__owner, nexus_stats__kills, nexus_stats__score, nexus_mvp__owner, nexus_mvp__stats, nexus_mvp__score)
    return true

  find_query() <| $ [es(REQUIRE=nexus_mvp_current_round)] (nexus_mvp__reason : int;
                                                           nexus_mvp__team : int;
                                                           var nexus_mvp__owner : EntityId&;
                                                           var nexus_mvp__stats : EntityId&;
                                                           var nexus_mvp__score : int&)
    if nexus_mvp__reason != int(NexusMvpReason.MOST_KILLS) || nexus_mvp__team != nexus_stats__team
      return false
    try_get_mvp_for_most_kills(eid, nexus_stats__owner, nexus_stats__kills, nexus_stats__score, nexus_mvp__owner, nexus_mvp__stats, nexus_mvp__score)
    return true


[es(tag=server, REQUIRE=nexus_stats_total, track=(nexus_stats__assists, nexus_stats__beaconResets, nexus_stats__score))]
def nexus_mvp_try_get_most_assists_for_game(evt : Event;
                                            eid : EntityId;
                                            nexus_stats__owner : EntityId;
                                            nexus_stats__team : int;
                                            nexus_stats__assists : int;
                                            nexus_stats__beaconResets : int;
                                            nexus_stats__score : int)
  find_query() <| $ [es(REQUIRE=nexus_mvp_total, REQUIRE_NOT=nexus_mvp__team)] (nexus_mvp__reason : int;
                                                                                var nexus_mvp__owner : EntityId&;
                                                                                var nexus_mvp__stats : EntityId&;
                                                                                var nexus_mvp__score : int&)
    if nexus_mvp__reason != int(NexusMvpReason.MOST_HELP)
      return false
    try_get_mvp_for_most_help(eid, nexus_stats__owner, nexus_stats__assists, nexus_stats__beaconResets, nexus_stats__score, nexus_mvp__owner, nexus_mvp__stats, nexus_mvp__score)
    return true

  find_query() <| $ [es(REQUIRE=nexus_mvp_total)] (nexus_mvp__reason : int;
                                                   nexus_mvp__team : int;
                                                   var nexus_mvp__owner : EntityId&;
                                                   var nexus_mvp__stats : EntityId&;
                                                   var nexus_mvp__score : int&)
    if nexus_mvp__reason != int(NexusMvpReason.MOST_HELP) || nexus_mvp__team != nexus_stats__team
      return false
    try_get_mvp_for_most_help(eid, nexus_stats__owner, nexus_stats__assists, nexus_stats__beaconResets, nexus_stats__score, nexus_mvp__owner, nexus_mvp__stats, nexus_mvp__score)
    return true


[es(tag=server, REQUIRE=nexus_stats_current_round, track=(nexus_stats__assists, nexus_stats__beaconResets, nexus_stats__score))]
def nexus_mvp_try_get_most_assists_for_round(evt : Event;
                                             eid : EntityId;
                                             nexus_stats__owner : EntityId;
                                             nexus_stats__team : int;
                                             nexus_stats__assists : int;
                                             nexus_stats__beaconResets : int;
                                             nexus_stats__score : int)
  find_query() <| $ [es(REQUIRE=nexus_mvp_current_round, REQUIRE_NOT=nexus_mvp__team)] (nexus_mvp__reason : int;
                                                                                        var nexus_mvp__owner : EntityId&;
                                                                                        var nexus_mvp__stats : EntityId&;
                                                                                        var nexus_mvp__score : int&)
    if nexus_mvp__reason != int(NexusMvpReason.MOST_HELP)
      return false
    try_get_mvp_for_most_help(eid, nexus_stats__owner, nexus_stats__assists, nexus_stats__beaconResets, nexus_stats__score, nexus_mvp__owner, nexus_mvp__stats, nexus_mvp__score)
    return true

  find_query() <| $ [es(REQUIRE=nexus_mvp_current_round)] (nexus_mvp__reason : int;
                                                           nexus_mvp__team : int;
                                                           var nexus_mvp__owner : EntityId&;
                                                           var nexus_mvp__stats : EntityId&;
                                                           var nexus_mvp__score : int&)
    if nexus_mvp__reason != int(NexusMvpReason.MOST_HELP) || nexus_mvp__team != nexus_stats__team
      return false
    try_get_mvp_for_most_help(eid, nexus_stats__owner, nexus_stats__assists, nexus_stats__beaconResets, nexus_stats__score, nexus_mvp__owner, nexus_mvp__stats, nexus_mvp__score)
    return true


[es(tag=server, REQUIRE=nexus_stats_total, track=(nexus_stats__beaconCaptures, nexus_stats__score))]
def nexus_mvp_try_get_most_beacon_captures_for_game(evt : Event;
                                                    eid : EntityId;
                                                    nexus_stats__owner : EntityId;
                                                    nexus_stats__team : int;
                                                    nexus_stats__beaconCaptures : int;
                                                    nexus_stats__score : int)
  find_query() <| $ [es(REQUIRE=nexus_mvp_total, REQUIRE_NOT=nexus_mvp__team)] (nexus_mvp__reason : int;
                                                                                var nexus_mvp__owner : EntityId&;
                                                                                var nexus_mvp__stats : EntityId&;
                                                                                var nexus_mvp__score : int&)
    if nexus_mvp__reason != int(NexusMvpReason.MOST_BEACON_CAPTURES)
      return false
    try_get_mvp_for_most_beacon_captures(eid, nexus_stats__owner, nexus_stats__beaconCaptures, nexus_stats__score, nexus_mvp__owner, nexus_mvp__stats, nexus_mvp__score)
    return true

  find_query() <| $ [es(REQUIRE=nexus_mvp_total)] (nexus_mvp__reason : int;
                                                   nexus_mvp__team : int;
                                                   var nexus_mvp__owner : EntityId&;
                                                   var nexus_mvp__stats : EntityId&;
                                                   var nexus_mvp__score : int&)
    if nexus_mvp__reason != int(NexusMvpReason.MOST_BEACON_CAPTURES) || nexus_mvp__team != nexus_stats__team
      return false
    try_get_mvp_for_most_beacon_captures(eid, nexus_stats__owner, nexus_stats__beaconCaptures, nexus_stats__score, nexus_mvp__owner, nexus_mvp__stats, nexus_mvp__score)
    return true


[es(tag=server, REQUIRE=nexus_stats_current_round, track=(nexus_stats__beaconCaptures, nexus_stats__score))]
def nexus_mvp_try_get_most_beacon_captures_for_round(evt : Event;
                                                     eid : EntityId;
                                                     nexus_stats__owner : EntityId;
                                                     nexus_stats__team : int;
                                                     nexus_stats__beaconCaptures : int;
                                                     nexus_stats__score : int)
  find_query() <| $ [es(REQUIRE=nexus_mvp_current_round, REQUIRE_NOT=nexus_mvp__team)] (nexus_mvp__reason : int;
                                                                                        var nexus_mvp__owner : EntityId&;
                                                                                        var nexus_mvp__stats : EntityId&;
                                                                                        var nexus_mvp__score : int&)
    if nexus_mvp__reason != int(NexusMvpReason.MOST_BEACON_CAPTURES)
      return false
    try_get_mvp_for_most_beacon_captures(eid, nexus_stats__owner, nexus_stats__beaconCaptures, nexus_stats__score, nexus_mvp__owner, nexus_mvp__stats, nexus_mvp__score)
    return true

  find_query() <| $ [es(REQUIRE=nexus_mvp_current_round)] (nexus_mvp__reason : int;
                                                           nexus_mvp__team : int;
                                                           var nexus_mvp__owner : EntityId&;
                                                           var nexus_mvp__stats : EntityId&;
                                                           var nexus_mvp__score : int&)
    if nexus_mvp__reason != int(NexusMvpReason.MOST_BEACON_CAPTURES) || nexus_mvp__team != nexus_stats__team
      return false
    try_get_mvp_for_most_beacon_captures(eid, nexus_stats__owner, nexus_stats__beaconCaptures, nexus_stats__score, nexus_mvp__owner, nexus_mvp__stats, nexus_mvp__score)
    return true
