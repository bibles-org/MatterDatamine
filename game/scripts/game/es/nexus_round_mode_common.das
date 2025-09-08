module nexus_round_mode_common shared

require game.utils.team
require game.es.nexus_common
require ecs.enum_macro
require ecs


[export_enum]
enum NexusRoundFinishReason
  ALL_DIED
  TEAM_DIED
  CAPTURE
  CAPTURE_ADVANTAGE
  POINTS
  POINTS_ADVANTAGE
  POINTS_DRAW
  TIME_OUT


[export_enum]
enum NexusRoundState
  None
  Preparation
  Started
  Finished
  Debriefing


def is_points_mode()
  return find_query() <| $ [es(REQUIRE=(nexus_game_controller, nexus_round_mode, nexus_round_mode_points))] () => true


def is_eviction_mode() : bool
  return find_query() <| $ [es(REQUIRE=(nexus_game_controller, nexus_round_mode, nexus_round_mode_eviction))] () => true


def is_round_state(state : NexusRoundState) : bool
  return find_query() <| $ [es] (nexus_round_mode_game_controller__roundState : int) => nexus_round_mode_game_controller__roundState == int(state)


def get_round_number() : int
  var number = 0
  find_query() <| $ [es] (nexus_round_mode_game_controller__roundNumber : int)
    number = nexus_round_mode_game_controller__roundNumber
    return true
  return number
