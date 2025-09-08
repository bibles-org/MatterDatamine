from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { giant_txt, body_txt, h2_txt } = require("%ui/fonts_style.nut")
let { RedWarningColor, TextHighlight, VictoryColor } = require("%ui/components/colors.nut")
let { mkText, mkMonospaceTimeComp } = require("%ui/components/commonComponents.nut")
let { nexusRoundModeRoundEnded, nexusRoundModeRoundEndWinner, nexusRoundModeAllyTeam,
  nexusRoundModeEnemyTeam, isNexusDebriefingState, nexusRoundModeRoundNumber, nexusRoundModeDebriefingAt,
  nexusRoundModeRoundEndReason } = require("%ui/hud/state/nexus_round_mode_state.nut")
let { wrapInStdPanel } = require("%ui/mainMenu/stdPanel.nut")
let { teamStatsBlock, fillPlayersToGetStats, statsToShow, TOTAL_STATS_ID, mkMvpBlock
} = require("%ui/hud/menus/nexus_stats.nut")
let { isNexus } = require("%ui/hud/state/nexus_mode_state.nut")
let { areHudMenusOpened } = require("%ui/hud/hud_menus_state.nut")
let { nexusRoundEndReasonMap } = require("%ui/hud/tips/nexus_round_mode_round_result.nut")
let { addInteractiveElement, removeInteractiveElement } = require("%ui/hud/state/interactive_state.nut")
let { sound_play } = require("%dngscripts/sound_system.nut")
let { mkCountdownTimerPerSec } = require("%ui/helpers/timers.nut")

const ANIM_STEP_DURATION = 0.4

function victoryDefeatBlock() {
  let winDefeat = nexusRoundModeRoundEndWinner.get() == nexusRoundModeAllyTeam.get() ? loc("nexus/victory")
    : nexusRoundModeRoundEndWinner.get() == nexusRoundModeEnemyTeam.get() ? loc("nexus/defeat")
    : loc("nexus/draw")
  let color = nexusRoundModeRoundEndWinner.get() == nexusRoundModeAllyTeam.get() ? VictoryColor
    : nexusRoundModeRoundEndWinner.get() == nexusRoundModeEnemyTeam.get() ? RedWarningColor
    : TextHighlight
  let reasonLocId = nexusRoundEndReasonMap?[nexusRoundModeRoundEndReason.get()]
  return {
    watch = [nexusRoundModeRoundEnded, nexusRoundModeRoundEndWinner, nexusRoundModeAllyTeam, nexusRoundModeEnemyTeam, nexusRoundModeRoundEndReason]
    hplace = ALIGN_CENTER
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    transform = {}
    animations = [{ prop = AnimProp.translate, from = [0, -sh(30)], to = [0, 0], duration = ANIM_STEP_DURATION,
      play = true, easing = InOutCubic, onStart = sound_play("ui_sounds/interface_open") }]
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
      transform = const {}
      animations = const [
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
  let timer = mkCountdownTimerPerSec(nexusRoundModeDebriefingAt)
  return function() {
    if (timer.get() <= 0)
      return { watch = [timer, nexusRoundModeDebriefingAt] }
    return {
      watch = [timer, nexusRoundModeDebriefingAt]
      rendObj = ROBJ_WORLD_BLUR_PANEL
      valign = ALIGN_CENTER
      hplace = ALIGN_CENTER
      flow = FLOW_HORIZONTAL
      gap = const hdpx(10)
      padding = const [0, hdpx(6)]
      margin = [fsh(4), 0,0,0]
      children = [
        mkText(loc("nexus/roundStartTimer"), const { color = TextHighlight }.__update(h2_txt))
        mkMonospaceTimeComp(timer.get(), h2_txt, const mul_color(TextHighlight, Color(220,120,120)))
      ]
    }
  }
}

function roundDebriefingUi() {
  if (!isNexus.get())
    return { watch = isNexus }
  if (!isNexusDebriefingState.get() || areHudMenusOpened.get())
    return { watch = [isNexusDebriefingState, isNexus, areHudMenusOpened] }

  return {
    watch = [isNexusDebriefingState, isNexus, areHudMenusOpened]
    size = flex()
    children = [
      mkNextRoundTimer()
      wrapInStdPanel("nexusRoundDebriefing", roundDebriefing, null, null, { size = [0, 0] })
    ]
  }
}

return { roundDebriefingUi }
