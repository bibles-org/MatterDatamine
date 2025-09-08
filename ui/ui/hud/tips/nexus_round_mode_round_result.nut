from "%ui/ui_library.nut" import *

let { giant_txt, h2_txt } = require("%ui/fonts_style.nut")
let { isNexusRoundMode } = require("%ui/hud/state/nexus_mode_state.nut")
let { nexusRoundModeRoundEnded, nexusRoundModeRoundEndWinner, nexusRoundModeRoundEndReason, nexusRoundModeAllyTeam, nexusRoundModeEnemyTeam } = require("%ui/hud/state/nexus_round_mode_state.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { RedWarningColor, GreenSuccessColor, TextHighlight, ItemBgColor } = require("%ui/components/colors.nut")
let { NexusRoundFinishReason } = require("%sqGlob/dasenums.nut")

const ANIM_DURATION = 0.7

let winDefeatBg = {
  rendObj = ROBJ_SOLID
  size = [sw(20), sh(10)]
  color = ItemBgColor
  transform = {}
  animations = [{ prop=AnimProp.translate, from=[-sw(20), 0], to=[0, 0],
    duration = ANIM_DURATION, play = true, easing = OutCubic }]
}

let nexusRoundEndReasonMap = {
  [NexusRoundFinishReason.ALL_DIED] = "nexus_round_mode_round_finish/all_died",
  [NexusRoundFinishReason.TEAM_DIED] = "nexus_round_mode_round_finish/team_died",
  [NexusRoundFinishReason.CAPTURE] = "nexus_round_mode_round_finish/capture",
  [NexusRoundFinishReason.CAPTURE_ADVANTAGE] = "nexus_round_mode_round_finish/capture_advantage",
  [NexusRoundFinishReason.POINTS] = "nexus_round_mode_round_finish/points",
  [NexusRoundFinishReason.POINTS_ADVANTAGE] = "nexus_round_mode_round_finish/points_advantage",
  [NexusRoundFinishReason.POINTS_DRAW] = "nexus_round_mode_round_finish/points_draw",
  [NexusRoundFinishReason.TIME_OUT] = "nexus_round_mode_round_finish/time_out"
}

function winnerBlock() {
  if (!nexusRoundModeRoundEnded.get())
    return { watch = [nexusRoundModeRoundEnded, nexusRoundModeRoundEndWinner, nexusRoundModeAllyTeam, nexusRoundModeEnemyTeam] }



  let text = nexusRoundModeRoundEndWinner.get() == nexusRoundModeAllyTeam.get() ? loc("nexus/victory")
    : nexusRoundModeRoundEndWinner.get() == nexusRoundModeEnemyTeam.get() ? loc("nexus/defeat")
    : loc("nexus/draw")

  let color = nexusRoundModeRoundEndWinner.get() == nexusRoundModeAllyTeam.get() ? GreenSuccessColor
    : nexusRoundModeRoundEndWinner.get() == nexusRoundModeEnemyTeam.get() ? RedWarningColor
    : TextHighlight

  return {
    watch = [nexusRoundModeRoundEnded, nexusRoundModeRoundEndWinner, nexusRoundModeAllyTeam, nexusRoundModeEnemyTeam]
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
    size = [sw(10), sh(5)]
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

return {
  nexusRoundResultBlock
  nexusRoundEndReasonMap
}
