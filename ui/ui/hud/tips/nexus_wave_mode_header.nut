from "%ui/hud/state/nexus_mode_state.nut" import NexusGameStartState
from "%ui/fonts_style.nut" import h2_txt
from "%ui/components/colors.nut" import RedWarningColor
from "%ui/hud/tips/nexus_header_components.nut" import topHeaderBlock, nexusBeaconsBlock, mkTeamPoints,
  pointsBarWidth, mkNexusTimer

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { isNexusWaveMode, isNexusGameStarted, nexusModeTeamColors, isNexusGameFinished, isNexusPlayerSpawned,
  nexusStartGameState, nexusStartGameStateEndAll, nexusAllyTeam, nexusEnemyTeam } = require("%ui/hud/state/nexus_mode_state.nut")
let { nexusWaveModeNextGameEndTimer } = require("%ui/hud/state/nexus_wave_mode_state.nut")
let { nexusNextDelayedSpawnAt } = require("%ui/hud/state/nexus_spawn_state.nut")
let { localPlayerTeam } = require("%ui/hud/state/local_player.nut")
let { nexusPlayersConnected, nexusPlayersNeedToStart } = require("%ui/hud/state/nexus_players_state.nut")

let timerSize = [hdpx(100), hdpx(33)]

function mkTimerBlock() {
  return function() {
    let state = nexusStartGameState.get()
    let gameStateEnd = nexusStartGameStateEndAll.get()
    let res = isNexusGameFinished.get() ? null
      : nexusNextDelayedSpawnAt.get() > 0 && !isNexusPlayerSpawned.get() ? mkNexusTimer(nexusNextDelayedSpawnAt, loc("nexus/nextWaveTimer"))
      : nexusWaveModeNextGameEndTimer.get() > 0 ? mkNexusTimer(nexusWaveModeNextGameEndTimer, loc("nexus/drawTimer"))
      : ( state == NexusGameStartState.WarmUp || state == NexusGameStartState.WaitingForPlayers ) && gameStateEnd > 0 ? mkNexusTimer(nexusStartGameStateEndAll,
          state == NexusGameStartState.WaitingForPlayers ? loc("nexus_game_start/waitForPlayersTimer", {
          connected = nexusPlayersConnected.get()
          needed = nexusPlayersNeedToStart.get()
        }) : loc("nexus_game_start/waitForPlayers"))
      : null

    return {
      watch = [localPlayerTeam, nexusStartGameStateEndAll, nexusStartGameState, isNexusPlayerSpawned,
        nexusPlayersConnected, nexusPlayersNeedToStart, isNexusGameFinished, nexusNextDelayedSpawnAt, nexusWaveModeNextGameEndTimer]
      size = [SIZE_TO_CONTENT, timerSize[1]]
      children = res
    }
  }
}

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
            minWidth = pointsBarWidth*2
            children = [
              !isNexusGameStarted.get() ? null
                : mkTeamPoints(nexusEnemyTeam.get(), nexusModeTeamColors.get()[1], true)
              nexusBeaconsBlock
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

function nexusWaveHeaderBlock() {
  let watch = isNexusWaveMode
  if (!isNexusWaveMode.get())
    return static { watch }
  return {
    watch
    halign = ALIGN_CENTER
    children = altNexusScoreTip
  }
}

return {
  nexusWaveHeaderBlock
}
