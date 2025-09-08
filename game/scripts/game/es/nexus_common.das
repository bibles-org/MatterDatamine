module nexus_common shared
require ecs
require net
require player
require math.base
require ecs.enum_macro
require ecs.safe
require DagorSystem
require game.events.events_active_matter


[export_enum]
enum NexusTeam
  FIRST = 2
  SECOND = 3


def nexus_log(subsystem, message : string)
  print("[NEXUS {subsystem}] {message}")

def nexus_log(message : string)
  print("[NEXUS] {message}")

def nexus_logwarn(subsystem, message : string)
  logwarn("[NEXUS {subsystem}] {message}")

def nexus_logwarn(message : string)
  logwarn("[NEXUS] {message}")

def nexus_logerr(subsystem, message : string)
  logerr("[NEXUS {subsystem}] {message}")

def nexus_logerr(message : string)
  logerr("[NEXUS] {message}")


def is_game_started() : bool
  return find_query() <| $ [es] (nexus_game_controller__isGameStarted : bool) => nexus_game_controller__isGameStarted

def is_round_mode() : bool
  return find_query() <| $ [es(REQUIRE=(nexus_game_controller, nexus_round_mode))] () => true


def is_any_teammate_alive(team_id : int)
  return find_query() <| $ [es(REQUIRE=nexus_militant, REQUIRE_NOT=deadEntity)] (team : int; isAlive : bool)
    return isAlive && team == team_id


def get_teammate_alive_count(team_id : int)
  var count = 0
  query() <| $ [es(REQUIRE=nexus_militant, REQUIRE_NOT=deadEntity)] (team : int; isAlive : bool)
    if isAlive && team == team_id
      ++count
  return count


def get_teammates(team_id : int) : array<EntityId>
  var teammates : array<EntityId>
  query() <| $ [es(REQUIRE=nexus_militant, REQUIRE_NOT=deadEntity)] (eid : EntityId;
                                                                     team : int;
                                                                     isAlive : bool)
    if isAlive && team == team_id
      teammates |> push(eid)
  return <- teammates


def get_nexus_mode()
  var result = ""
  find_query() <| $ [es(REQUIRE=nexus_game_controller)] (nexus_round_mode : Tag const?;
                                                         nexus_wave_mode : Tag const?)
    if nexus_round_mode != null
      result = "round"
    elif nexus_wave_mode != null
      result = "wave"
    return true
  return result


def get_other_team(team : int)
  return (team == int(NexusTeam.FIRST) ? int(NexusTeam.SECOND)
        : team == int(NexusTeam.SECOND) ? int(NexusTeam.FIRST)
        : TEAM_UNASSIGNED)


def get_team_eid(team_to_find : int)
  var teamEid = INVALID_ENTITY_ID
  find_query() <| $ [es(REQUIRE=nexus_team)] (eid : EntityId;
                                              team__id : int)
    if team_to_find != team__id
      return false
    teamEid = eid
    return true
  return teamEid
