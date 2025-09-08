from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
let { NexusRoundState, NexusTeam, NexusGameEndState } = require("%sqGlob/dasenums.nut")
let { EventNexusRoundModeRoundFinished, EventNexusRoundModeRoundChange, EventNexusGameEnd, EventNexusGameDebriefing
} = require("dasevents")
let { switch_to_menu_scene } = require("%sqGlob/app_control.nut")
let { get_sync_time } = require("net")

let nexusRoundModeTeamScores = Watched({})
let nexusRoundModeTeamPoints = Watched({})
let nexusRoundModeRoundsToWin = Watched(-1)
let nexusRoundModePointsToWin = Watched(-1.0)
let nexusRoundModeRoundNumber = Watched(-1)
let nexusRoundModeRoundStartAt = Watched(-1.0)
let nexusRoundModeRoundDrawAt = Watched(-1.0)
let nexusRoundModeDebriefingAt = Watched(-1.0)
let nexusRoundModeRoundChangeAt = Watched(-1.0)
let nexusRoundModeRoundEnded = Watched(false)
let nexusRoundModeRoundEndWinner = Watched(-1)
let nexusRoundModeRoundEndReason = Watched(-1)
let nexusRoundModeAbandonedTimer = Watched(-1)
let isNexusDebriefingState = Watched(false)
let isNesusEndGameDebriefing = Watched(false)
let nexusRoundModeGameWinner = Watched(-1)
let nexusRoundModeGameEndTimer = Watched(-1)

let nexusRoundModeAllyTeam = Watched(-1)
let nexusRoundModeEnemyTeam = Computed(@() nexusRoundModeAllyTeam.get() == NexusTeam.FIRST ? NexusTeam.SECOND : NexusTeam.FIRST)

ecs.register_es("nexus_round_mode_track_team_scores_es", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp) {
    nexusRoundModeTeamScores.mutate(@(scores) scores[comp.team__id] <- comp.nexus_round_mode_team__wonRounds)
  }
  onDestroy = function(_evt, _eid, comp) {
    nexusRoundModeTeamScores.mutate(@(scores) scores.$rawdelete($"{comp.team__id}"))
  }
}, {
  comps_track = [
    ["nexus_round_mode_team__wonRounds", ecs.TYPE_INT],
  ]
  comps_ro = [["team__id", ecs.TYPE_INT]]
},
{
  tags = "gameClient"
})


ecs.register_es("nexus_round_mode_track_team_points_es", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp) {
    nexusRoundModeTeamPoints.mutate(@(points) points[comp.team__id] <- comp.nexus_round_mode_team__displayPoints)
  }
  onDestroy = function(_evt, _eid, comp) {
    nexusRoundModeTeamPoints.mutate(@(points) points.$rawdelete($"{comp.team__id}"))
  }
}, {
  comps_track = [
    ["nexus_round_mode_team__displayPoints", ecs.TYPE_FLOAT],
  ]
  comps_ro = [["team__id", ecs.TYPE_INT]]
},
{
  tags = "gameClient"
})


ecs.register_es("nexus_round_mode_init_rounds_to_win_es", {
  onInit = function(_evt, _eid, comp) {
    nexusRoundModeRoundsToWin.set(comp.nexus_round_mode_game_controller__roundsToWin)
    nexusRoundModePointsToWin.set(comp.nexus_round_mode_game_controller__pointsToWin)
  }
  onDestroy = function(...) {
    nexusRoundModeRoundsToWin.set(-1)
    nexusRoundModePointsToWin.set(-1.0)
  }
}, {
  comps_ro = [
    ["nexus_round_mode_game_controller__roundsToWin", ecs.TYPE_INT],
    ["nexus_round_mode_game_controller__pointsToWin", ecs.TYPE_FLOAT, -1.0]
  ]
},
{
  tags = "gameClient"
})


ecs.register_es("nexus_round_mode_track_round_number_es", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp) {
    nexusRoundModeRoundNumber.set(comp.nexus_round_mode_game_controller__roundNumber)
  }
  onDestroy = function(...) {
    nexusRoundModeRoundNumber.set(-1)
  }
}, {
  comps_track = [
    ["nexus_round_mode_game_controller__roundNumber", ecs.TYPE_INT]
  ]
},
{
  tags = "gameClient"
})


ecs.register_es("nexus_round_mode_track_draw_timer_es", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp) {
    nexusRoundModeRoundDrawAt.set(comp.nexus_round_mode_game_controller__timeOutAt)
  }
  onDestroy = function(...) {
    nexusRoundModeRoundDrawAt.set(-1.0)
  }
}, {
  comps_track = [["nexus_round_mode_game_controller__timeOutAt", ecs.TYPE_FLOAT]]
}, {tags = "gameClient"})

ecs.register_es("nexus_round_mode_ally_team_es", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp){
    if (!comp.is_local)
      return
    nexusRoundModeAllyTeam.set(comp.team)
  },
},
{
  comps_track = [
    ["team", ecs.TYPE_INT],
    ["is_local", ecs.TYPE_BOOL]
  ]
},
{
  tags = "gameClient"
})

ecs.register_es("nexus_round_mode_track_round_end_es", {
  [[EventNexusRoundModeRoundFinished]] = function(evt, _eid, comp){
    if (!comp.is_local)
      return
    nexusRoundModeRoundEnded.set(true)
    nexusRoundModeRoundEndWinner.set(evt.winnerTeam)
    nexusRoundModeRoundEndReason.set(evt.reason)
  },
  [[EventNexusRoundModeRoundChange]] = function(_evt, _eid, comp){
    if (!comp.is_local)
      return
    nexusRoundModeRoundEnded.set(false)
    nexusRoundModeRoundEndWinner.set(-1)
    nexusRoundModeRoundEndReason.set(-1)
  },
  [[EventNexusGameEnd]] = function(evt, _eid, comp){
    if (!comp.is_local)
      return
    nexusRoundModeGameWinner.set(evt.winner)
  },
  [[EventNexusGameDebriefing]] = function(_evt, _eid, comp) {
    if (!comp.is_local)
      return
    isNesusEndGameDebriefing.set(true)
  }
},
{
  comps_ro = [
    ["team", ecs.TYPE_INT],
    ["is_local", ecs.TYPE_BOOL],
  ]
},
{
  tags = "gameClient"
})

ecs.register_es("nexus_round_mode_reset_data_on_game_start", {
  onInit = function(...) {
    nexusRoundModeRoundEnded.set(false)
    nexusRoundModeRoundEndWinner.set(-1)
    nexusRoundModeRoundEndReason.set(-1)
    nexusRoundModeGameWinner.set(-1)
    isNesusEndGameDebriefing.set(false)
    nexusRoundModeGameEndTimer.set(-1)
  }
},
{
  comps_rq = [ "nexus_round_mode" ]
},
{
  tags = "gameClient"
})

ecs.register_es("nexus_round_mode_exit_battle", {
  [["onInit", "onChange"]] = function(_evt, _eid, comp) {
    if (comp.nexus_game_end__state == NexusGameEndState.ClientsLeave)
      switch_to_menu_scene()
    if (comp.nexus_game_end__state == NexusGameEndState.Debriefing && comp.nexus_game_end__debriefingTime > 0)
      nexusRoundModeGameEndTimer.set(comp.nexus_game_end__debriefingTime + get_sync_time())
  }
  onDestroy = @(...) nexusRoundModeGameEndTimer.set(-1)
},
{
  comps_track = [["nexus_game_end__state", ecs.TYPE_INT], ["nexus_game_end__debriefingTime", ecs.TYPE_FLOAT]]
})

ecs.register_es("nexus_round_mode_track_round_state_es", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp){
    nexusRoundModeRoundStartAt.set(-1.0)
    nexusRoundModeRoundChangeAt.set(-1.0)
    nexusRoundModeDebriefingAt.set(-1.0)
    isNexusDebriefingState.set(false)

    let state = comp.nexus_round_mode_game_controller__roundState
    if (state == NexusRoundState.Preparation)
      nexusRoundModeRoundStartAt.set(comp.nexus_round_mode_game_controller__roundStateEndAt)
    else if (state == NexusRoundState.Finished)
      nexusRoundModeRoundChangeAt.set(comp.nexus_round_mode_game_controller__roundStateEndAt)
    else if (state == NexusRoundState.Debriefing) {
      nexusRoundModeDebriefingAt.set(comp.nexus_round_mode_game_controller__roundStateEndAt)
      isNexusDebriefingState.set(true)
    }
  }
},
{
  comps_track = [
    ["nexus_round_mode_game_controller__roundState", ecs.TYPE_INT],
    ["nexus_round_mode_game_controller__roundStateEndAt", ecs.TYPE_FLOAT]
  ]
},
{
  tags = "gameClient"
})

ecs.register_es("nexus_round_mode_team_abandoned_timer_es", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp){
    nexusRoundModeAbandonedTimer.set(comp.nexus_team_abandoned_timer__finishAt)
  },
  [["onDestroy"]] = @() nexusRoundModeAbandonedTimer.set(-1)
},
{
  comps_track = [
    ["nexus_team_abandoned_timer__finishAt", ecs.TYPE_FLOAT],
  ]
},
{
  tags = "gameClient"
})

return {
  nexusRoundModeTeamScores
  nexusRoundModeTeamPoints
  nexusRoundModeRoundsToWin
  nexusRoundModePointsToWin
  nexusRoundModeRoundNumber
  nexusRoundModeRoundStartAt
  nexusRoundModeRoundDrawAt
  nexusRoundModeRoundChangeAt
  nexusRoundModeRoundEnded
  nexusRoundModeRoundEndWinner
  nexusRoundModeRoundEndReason
  nexusRoundModeAllyTeam
  nexusRoundModeEnemyTeam
  nexusRoundModeAbandonedTimer
  nexusRoundModeDebriefingAt
  isNexusDebriefingState
  nexusRoundModeGameWinner
  isNesusEndGameDebriefing
  nexusRoundModeGameEndTimer
}
