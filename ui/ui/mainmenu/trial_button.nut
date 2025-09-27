from "%ui/fonts_style.nut" import h2_txt, body_txt, sub_txt
from "%ui/components/colors.nut" import InfoTextValueColor, RedFailColor, RedWarningColor
from "%ui/components/commonComponents.nut" import mkTextArea
from "%ui/components/button.nut" import textButton
from "%ui/components/cursors.nut" import setTooltip
from "%ui/profile/profileState.nut" import trialData, playerStats
from "%ui/mainMenu/currencyPanel.nut" import showNotEnoughPremiumMsgBox
from "%ui/components/glareAnimation.nut" import glareAnimation, animChildren
import "%ui/components/tooltipBox.nut" as tooltipBox
import "%ui/components/colorize.nut" as colorize
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "%ui/helpers/time.nut" import secondsToStringLoc
from "%ui/ui_library.nut" import *

function showEndDemoMsgBox(){
  let header = mkTextArea(loc("version/demoEndedText"), static { halign = ALIGN_CENTER, margin = [0, 0, hdpx(10), 0] }.__merge(h2_txt))
  showNotEnoughPremiumMsgBox(header, true)
}

let isTrialLimitExceeded = Computed(function() {
  local res = false
  if ((trialData.get()?.trialType??0) == 0)
    return res
  foreach (key, limits in (trialData.get()?.trialStatsLimit ?? {})) {
    let pStats = playerStats.get()?.stats[key]
    if (pStats == null)
      continue
    foreach (limitKey, limitVal in limits) {
      let statToCompare = pStats?[limitKey]
      if (statToCompare != null && statToCompare >= limitVal) {
        res = true
        break
      }
    }
  }
  return res
})

function mkDemoButton() {
  let {trialType = 0 } = trialData.get()
  if (trialType == 0 )
    return @() { watch = trialData }























  return function() {
    let color1 = Color(30, 70, 35, 220)
    let color2 = Color(46, 120, 50, 220)














    let header = @() {
      size = FLEX_H
      watch = isTrialLimitExceeded

      flow = FLOW_VERTICAL
      gap = hdpx(4)
      halign = ALIGN_CENTER
      children = [
        mkTextArea(trialType == 1 ? loc("version/demoTitleIsolated") : loc("version/demoTitle"),
         static { halign = ALIGN_CENTER, margin = [0, 0, hdpx(10), 0] }.__merge(h2_txt))
      ]
    }

    return {
      watch = [
        trialData, isTrialLimitExceeded, 
      ]
      children = textButton(isTrialLimitExceeded.get() ? loc("version/demoEnded") : loc("version/demo"),
        isTrialLimitExceeded.get() ? showEndDemoMsgBox : @() showNotEnoughPremiumMsgBox(header),
        {
          key = $"demoButton_{isTrialLimitExceeded.get()}"
          transform = static {}
          animations = isTrialLimitExceeded.get() ? null : [{ prop = AnimProp.fillColor, from = color1, to = color2,
            duration = 3, play = true, easing = CosineFull, loop = true }]
          margin = static [0, hdpx(20), 0,0]
          size = static [SIZE_TO_CONTENT, hdpx(30)]
          hplace = ALIGN_CENTER




        }.__merge(isTrialLimitExceeded.get() ? accentButtonStyle : { style = { BtnBgNormal = color1 }}))
    }
  }
}

return {
  mkDemoButton
  showEndDemoMsgBox
}