from "%dngscripts/sound_system.nut" import sound_play

from "%ui/hud/menus/nexus_stats.nut" import fillPlayersToGetStats, mkMvpBlock

from "%ui/fonts_style.nut" import giant_txt, body_txt, h2_txt
from "%ui/components/colors.nut" import RedWarningColor, TextHighlight, VictoryColor
from "%ui/components/commonComponents.nut" import mkText, mkTimeComp
from "%ui/mainMenu/stdPanel.nut" import wrapInStdPanel
from "%ui/hud/state/interactive_state.nut" import addInteractiveElement, removeInteractiveElement
from "%ui/helpers/timers.nut" import mkCountdownTimerPerSec

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { nexusRoundModeRoundEnded, nexusRoundModeRoundEndWinner, isNexusDebriefingState, nexusRoundModeRoundNumber, nexusRoundModeDebriefingAt, nexusRoundModeRoundEndReason } = require("%ui/hud/state/nexus_round_mode_state.nut")
let { teamStatsBlock, statsToShow, TOTAL_STATS_ID } = require("%ui/hud/menus/nexus_stats.nut")
let { isNexus, nexusAllyTeam, nexusEnemyTeam } = require("%ui/hud/state/nexus_mode_state.nut")
let { areHudMenusOpened } = require("%ui/hud/hud_menus_state.nut")
let { nexusRoundEndReasonMap } = require("%ui/hud/tips/nexus_round_mode_round_result.nut")

const ANIM_STEP_DURATION = 0.4

function victoryDefeatBlock() {
  let winDefeat = nexusRoundModeRoundEndWinner.get() == nexusAllyTeam.get() ? loc("nexus/victory")
    : nexusRoundModeRoundEndWinner.get() == nexusEnemyTeam.get() ? loc("nexus/defeat")
    : loc("nexus/draw")
  let color = nexusRoundModeRoundEndWinner.get() == nexusAllyTeam.get() ? VictoryColor
    : nexusRoundModeRoundEndWinner.get() == nexusEnemyTeam.get() ? RedWarningColor
    : TextHighlight
  let reasonLocId = nexusRoundEndReasonMap?[nexusRoundModeRoundEndReason.get()]
  return {
    watch = [nexusRoundModeRoundEnded, nexusRoundModeRoundEndWinner, nexusAllyTeam, nexusEnemyTeam, nexusRoundModeRoundEndReason]
    hplace = ALIGN_CENTER
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    transform = static {}
    animations = static [{ prop = AnimProp.translate, from = [0, -sh(30)], to = [0, 0], duration = ANIM_STEP_DURATION,
      play = true, easing = InOutCubic, onStart = @() sound_play("ui_sounds/interface_open") }]
    children = [
      mkText(winDefeat, { color }.__update(giant_txt))
      mkText(loc(reasonLocId), body_txt)
    ]
  }
}

let roundDebriefing = {
  size = flex()
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  padding = hdpx(10)
  onAttach = function() {
    statsToShow.set(nexusRoundModeRoundNumber.get())
    fillPlayersToGetStats()
    addInteractiveElement("nexusRoundDebriefing")
  }
  onDetach = function() {
    removeInteractiveElement("nexusRoundDebriefing")
    statsToShow.set(TOTAL_STATS_ID)
  }
  clipChildren = true
  children = [
    victoryDefeatBlock
    mkMvpBlock(ANIM_STEP_DURATION)
    {
      size = flex()
      transform = static {}
      animations = static [
        {
          prop = AnimProp.translate, from = [0, sh(100)], to = [0, sh(100)], duration = ANIM_STEP_DURATION * 3,
          play = true
        }
        {
          prop = AnimProp.translate, from = [0, sh(100)], to = [0, 0], duration = ANIM_STEP_DURATION,
          easing = InOutCubic, play = true, delay = ANIM_STEP_DURATION * 2
        }
      ]
      children = teamStatsBlock
    }
  ]
}

function mkNextRoundTimer() {
  let timer = mkCountdownTimerPerSec(nexusRoundModeDebriefingAt, "nextRoundTimer")
  return function() {
    if (timer.get() <= 0)
      return { watch = [timer, nexusRoundModeDebriefingAt] }
    return {
      watch = [timer, nexusRoundModeDebriefingAt]
      rendObj = ROBJ_WORLD_BLUR_PANEL
      valign = ALIGN_CENTER
      hplace = ALIGN_CENTER
      flow = FLOW_HORIZONTAL
      gap = static hdpx(10)
      padding = static [0, hdpx(6)]
      margin = static [fsh(4), 0,0,0]
      children = [
        mkText(loc("nexus/roundStartTimer"), static { color = TextHighlight }.__update(h2_txt))
        mkTimeComp(timer.get(), h2_txt, static mul_color(TextHighlight, Color(220,120,120)))
      ]
    }
  }
}

function roundDebriefingUi() {
  if (!isNexus.get())
    return { watch = isNexus }
  if (!isNexusDebriefingState.get() || areHudMenusOpened.get()) {
    gui_scene.clearTimer("nextRoundTimer")
    return { watch = [isNexusDebriefingState, isNexus, areHudMenusOpened] }
  }

  return {
    watch = [isNexusDebriefingState, isNexus, areHudMenusOpened]
    size = flex()
    children = [
      mkNextRoundTimer()
      wrapInStdPanel("nexusRoundDebriefing", roundDebriefing, null, null, static { size = 0 })
    ]
  }
}

return { roundDebriefingUi }
