from "%sqGlob/dasenums.nut" import NexusGameFinishReason

from "%ui/fonts_style.nut" import giant_txt, h2_txt
from "%ui/components/commonComponents.nut" import mkText
from "%ui/components/colors.nut" import RedWarningColor, GreenSuccessColor, TextHighlight, ItemBgColor

from "%ui/ui_library.nut" import *

let { isNexusRoundMode, nexusAllyTeam, nexusEnemyTeam } = require("%ui/hud/state/nexus_mode_state.nut")
let { nexusRoundModeRoundEnded, nexusRoundModeRoundEndWinner, nexusRoundModeRoundEndReason } = require("%ui/hud/state/nexus_round_mode_state.nut")

const ANIM_DURATION = 0.7

let winDefeatBg = static {
  rendObj = ROBJ_SOLID
  size = static [sw(20), sh(10)]
  color = ItemBgColor
  transform = {}
  animations = [{ prop=AnimProp.translate, from=[-sw(20), 0], to=[0, 0],
    duration = ANIM_DURATION, play = true, easing = OutCubic }]
}

let nexusRoundEndReasonMap = freeze({
  [NexusGameFinishReason.ALL_DIED] = "nexus_round_mode_round_finish/all_died",
  [NexusGameFinishReason.TEAM_DIED] = "nexus_round_mode_round_finish/team_died",
  [NexusGameFinishReason.CAPTURE] = "nexus_round_mode_round_finish/capture",
  [NexusGameFinishReason.CAPTURE_ADVANTAGE] = "nexus_round_mode_round_finish/capture_advantage",
  [NexusGameFinishReason.POINTS] = "nexus_round_mode_round_finish/points",
  [NexusGameFinishReason.POINTS_ADVANTAGE] = "nexus_round_mode_round_finish/points_advantage",
  [NexusGameFinishReason.POINTS_DRAW] = "nexus_round_mode_round_finish/points_draw",
  [NexusGameFinishReason.TIME_OUT] = "nexus_round_mode_round_finish/time_out"
})

function winnerBlock() {
  if (!nexusRoundModeRoundEnded.get())
    return { watch = [nexusRoundModeRoundEnded, nexusRoundModeRoundEndWinner, nexusAllyTeam, nexusEnemyTeam] }

  let text = nexusRoundModeRoundEndWinner.get() == nexusAllyTeam.get() ? loc("nexus/victory")
    : nexusRoundModeRoundEndWinner.get() == nexusEnemyTeam.get() ? loc("nexus/defeat")
    : loc("nexus/draw")

  let color = nexusRoundModeRoundEndWinner.get() == nexusAllyTeam.get() ? GreenSuccessColor
    : nexusRoundModeRoundEndWinner.get() == nexusEnemyTeam.get() ? RedWarningColor
    : TextHighlight

  return {
    watch = [nexusRoundModeRoundEnded, nexusRoundModeRoundEndWinner, nexusAllyTeam, nexusEnemyTeam]
    clipchildren = true
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      winDefeatBg
      mkText(text, {
        animations = [{ prop=AnimProp.translate, from = [sw(20),0], to = [0, 0],
          duration = ANIM_DURATION, play = true, easing=OutCubic }]
        color
      }.__update(giant_txt))
    ]
  }
}

function reasonBlock() {
  if (!nexusRoundModeRoundEnded.get())
    return { watch = [nexusRoundModeRoundEnded, nexusRoundModeRoundEndReason]  }

  let locKey = nexusRoundEndReasonMap?[nexusRoundModeRoundEndReason.get()]
  if (locKey == null)
    return { watch = [nexusRoundModeRoundEnded, nexusRoundModeRoundEndReason] }

  return {
    watch = [nexusRoundModeRoundEnded, nexusRoundModeRoundEndReason]
    rendObj = ROBJ_SOLID
    size = static [sw(10), sh(5)]
    padding = hdpx(10)
    minWidth = SIZE_TO_CONTENT
    transform = {}
    animations = [{ prop=AnimProp.translate, from = [0, sw(120)], to = [0, 0],
      duration = 0.5, play = true, easing = OutCubic }]
    color = ItemBgColor
    valign = ALIGN_CENTER
    halign = ALIGN_CENTER
    children = mkText(loc(locKey), { color = TextHighlight }.__update(h2_txt))
  }
}

function nexusRoundResultBlock() {
  let watch = [isNexusRoundMode, nexusRoundModeRoundEnded]
  if (!isNexusRoundMode.get() || !nexusRoundModeRoundEnded.get())
    return { watch }

  return {
    watch
    flow = FLOW_VERTICAL
    gap = hdpx(2)
    halign = ALIGN_CENTER
    children = [
      winnerBlock
      reasonBlock
    ]
  }
}

return freeze({
  nexusRoundResultBlock
  nexusRoundEndReasonMap
})
