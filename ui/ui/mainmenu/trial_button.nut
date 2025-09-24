from "%ui/fonts_style.nut" import h2_txt, body_txt, sub_txt
from "%ui/components/colors.nut" import InfoTextValueColor, RedFailColor, RedWarningColor
from "%ui/components/commonComponents.nut" import mkTextArea
from "%ui/components/button.nut" import textButton
from "%ui/components/cursors.nut" import setTooltip
from "%ui/profile/profileState.nut" import trialData, playerStats
from "%ui/mainMenu/currencyPanel.nut" import showNotEnoghPremiumMsgBox
from "%ui/components/glareAnimation.nut" import glareAnimation, animChildren
import "%ui/components/tooltipBox.nut" as tooltipBox
import "%ui/components/colorize.nut" as colorize
from "%ui/components/accentButton.style.nut" import accentButtonStyle
from "%ui/helpers/time.nut" import secondsToStringLoc
from "%ui/ui_library.nut" import *

function mkTrialButton() {
  let { trialStatsLimit = {}, trialType = 0 } = trialData.get()
  if (trialType == 0)
    return @() { watch = trialData }

  let isLimitExceeded = Computed(function() {
    local res = false
    foreach (key, limits in trialStatsLimit) {
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

  let statLimitsList = Computed(function() {
    let resLimits = []
    foreach (key, limits in trialStatsLimit) {
      let pStats = playerStats.get()?.stats[key]
      if (pStats == null)
        continue
      foreach (limitKey, limitVal in limits) {
        let statToCompare = pStats?[limitKey]
        if (statToCompare != null)
          resLimits.append({
            locKey = $"version/trial_{key}_{limitKey}"
            limitValue = limitVal
            pValue = statToCompare
            isExeeded = statToCompare >= limitVal
          })
      }
    }
    return resLimits
  })

  return function() {
    let color1 = Color(30, 70, 35, 220)
    let color2 = Color(46, 120, 50, 220)
    function mkLimits(font = sub_txt) {
      let limits = []
      foreach (limit in statLimitsList.get()) {
        let { locKey, limitValue, pValue, isExeeded } = limit
        limits.append(mkTextArea(loc(locKey, {
          limitValue = limitValue <= 100 ? limitValue : secondsToStringLoc(limitValue)
          pValue = colorize(isExeeded ? RedFailColor : InfoTextValueColor, limitValue <= 100 ? pValue : (pValue > 0.0 ? secondsToStringLoc(pValue) : "0"))
        }),
        { size = SIZE_TO_CONTENT }.__merge(font)))
      }
      return limits
    }

    let header = {
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = hdpx(4)
      halign = ALIGN_CENTER
      children = [
        mkTextArea(trialType == 1 ? loc("version/trialTitleIsolated") : loc("version/trialTitle"), { halign = ALIGN_CENTER, margin = [0, 0, hdpx(10), 0] }.__merge(h2_txt))
      ].extend(mkLimits(body_txt))
    }

    return {
      watch = [trialData, isLimitExceeded, statLimitsList]
      children = textButton(isLimitExceeded.get() ? loc("version/trialEnded") : loc("version/trial"),
        @() showNotEnoghPremiumMsgBox(header),
        {
          key = $"trialButton_{isLimitExceeded.get()}"
          transform = {}
          animations = isLimitExceeded.get() ? null : [{ prop = AnimProp.fillColor, from = color1, to = color2,
            duration = 3, play = true, easing = CosineFull, loop = true }]
          margin = [0, hdpx(20), 0,0]
          size = [SIZE_TO_CONTENT, hdpx(30)]
          hplace = ALIGN_CENTER
          onHover = @(on) setTooltip(!on ? null : tooltipBox({
            flow = FLOW_VERTICAL
            children = mkLimits()
          }))
        }.__merge(isLimitExceeded.get() ? accentButtonStyle : { style = { BtnBgNormal = color1 }}))
    }
  }
}

return { mkTrialButton }