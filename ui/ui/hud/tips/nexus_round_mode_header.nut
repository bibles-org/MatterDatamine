from "%sqstd/math.nut" import getRomanNumeral

from "%ui/hud/state/nexus_mode_state.nut" import NexusGameStartState

from "%ui/fonts_style.nut" import h2_txt
from "%ui/components/colors.nut" import RedWarningColor
from "%ui/components/commonComponents.nut" import mkText
from "%ui/hud/tips/nexus_header_components.nut" import topHeaderBlock, mkTeamPoints, pointsBarWidth, nexusBeaconsBlock,
  abandonTimerAnimtions, mkNexusTimer

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { isNexusGameStarted, isNexusRoundMode, nexusModeTeamColors, nexusStartGameState,
  nexusStartGameStateEndAll, nexusAllyTeam, nexusEnemyTeam } = require("%ui/hud/state/nexus_mode_state.nut")
let { nexusRoundModeRoundsToWin, nexusRoundModeTeamScores, nexusRoundModeRoundStartAt, nexusRoundModeRoundDrawAt,
  nexusRoundModeRoundEnded, nexusRoundModeRoundNumber, nexusRoundModeAbandonedTimer, nexusRoundModeDebriefingAt } = require("%ui/hud/state/nexus_round_mode_state.nut")
let { localPlayerTeam } = require("%ui/hud/state/local_player.nut")
let { nexusPlayersConnected, nexusPlayersNeedToStart } = require("%ui/hud/state/nexus_players_state.nut")

let timerSize = [hdpx(100), hdpx(33)]

let bgParams = {
  rendObj = ROBJ_WORLD_BLUR_PANEL
  fillColor = 0x220A0A0A
  color = 0xFFFFFFFF
}

function mkTimerBlock() {
  return function() {
    let state = nexusStartGameState.get()
    let gameStateEnd = nexusStartGameStateEndAll.get()
    let res = nexusRoundModeRoundEnded.get() ? null
      : nexusRoundModeDebriefingAt.get() > 0 ? mkNexusTimer(nexusRoundModeDebriefingAt, loc("nexus_game_start/debriefingTimer"))
      : nexusRoundModeAbandonedTimer.get() > 0 ? mkNexusTimer(nexusRoundModeAbandonedTimer,
        loc("nexus_game_start/abandonedTimer"), abandonTimerAnimtions)
      : nexusRoundModeRoundStartAt.get() > 0 ? mkNexusTimer(nexusRoundModeRoundStartAt, loc("nexus_game_start/startTimer"))
      : nexusRoundModeRoundDrawAt.get() > 0 ? mkNexusTimer(nexusRoundModeRoundDrawAt,
        loc("nexus/roundNumber",{ number = getRomanNumeral(nexusRoundModeRoundNumber.get())}))
      : ( state == NexusGameStartState.WarmUp || state == NexusGameStartState.WaitingForPlayers ) && gameStateEnd > 0 ? mkNexusTimer(nexusStartGameStateEndAll,
          state == NexusGameStartState.WaitingForPlayers ? loc("nexus_game_start/waitForPlayersTimer", {
          connected = nexusPlayersConnected.get()
          needed = nexusPlayersNeedToStart.get()
        }) : loc("nexus_game_start/waitForPlayers"))
      : null

    return {
      watch = [nexusRoundModeRoundStartAt, nexusRoundModeRoundDrawAt, nexusRoundModeRoundEnded,
        localPlayerTeam, nexusStartGameStateEndAll, nexusStartGameState, nexusRoundModeDebriefingAt,
        nexusRoundModeRoundNumber, nexusPlayersConnected, nexusPlayersNeedToStart, nexusRoundModeAbandonedTimer]
      size = [SIZE_TO_CONTENT, timerSize[1]]
      children = res
    }
  }
}

let mkTeamScore = @(score, color) {
  padding = static [0, hdpx(5)]
  children = mkText(score, { color }.__update(h2_txt))
}.__update(bgParams)


let bottomHeaderBlock = @() {
  size = FLEX_H
  hplace = ALIGN_CENTER
  halign = ALIGN_CENTER
  flow = FLOW_HORIZONTAL
  gap = static hdpx(20)
  valign = ALIGN_CENTER
  children = mkTimerBlock()
}


function altNexusScoreTip() {
  if (nexusAllyTeam.get() == -1)
    return static { watch = nexusAllyTeam}

  return {
    watch = nexusAllyTeam
    children = [
      topHeaderBlock()
      @() {
        watch = static [nexusAllyTeam, nexusEnemyTeam, isNexusGameStarted]
        flow = FLOW_VERTICAL
        gap = static hdpx(4)
        children = [
          {
            flow = FLOW_HORIZONTAL
            gap = static hdpx(6)
            valign = ALIGN_BOTTOM
            margin = static [hdpx(6), 0, 0,0]
            halign = ALIGN_CENTER
            minWidth = pointsBarWidth * 2
            children = [
              !isNexusGameStarted.get() ? null
                : mkTeamPoints(nexusEnemyTeam.get(), nexusModeTeamColors.get()[1], true)
              @() {
                watch = static [nexusRoundModeTeamScores, nexusRoundModeRoundsToWin]
                hplace = ALIGN_CENTER
                flow = FLOW_HORIZONTAL
                gap = static hdpx(10)
                valign = ALIGN_CENTER
                children = [
                  nexusRoundModeRoundsToWin.get() > 1 ? mkTeamScore(nexusRoundModeTeamScores.get()[nexusAllyTeam.get()], nexusModeTeamColors.get()[1]) : null
                  nexusBeaconsBlock
                  nexusRoundModeRoundsToWin.get() > 1 ? mkTeamScore(nexusRoundModeTeamScores.get()[nexusEnemyTeam.get()], RedWarningColor) : null
                ]
              }
              !isNexusGameStarted.get()? null
                : mkTeamPoints(nexusAllyTeam.get(), RedWarningColor, false)
            ]
          }
          bottomHeaderBlock
        ]
      }
    ]
  }
}

function nexusHeaderBlock() {
  let watch = isNexusRoundMode
  if (!isNexusRoundMode.get())
    return static { watch }
  return {
    watch
    halign = ALIGN_CENTER
    children = altNexusScoreTip
  }
}

return {
  nexusHeaderBlock
}
