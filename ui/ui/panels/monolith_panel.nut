from "%ui/mainMenu/monolith/monolithMenu.nut" import getMonolithNotifications
from "%ui/panels/console_common.nut" import mkFlashingInviteTextScreen, flashingScreen, mkStdPanel,
textColor, waitingCursor, inviteText, consoleFontSize, consoleTitleFontSize, mkNotificationIndicator
from "%ui/leaderboard/lb_state_base.nut" import curMonolithLbData, curMonolithLbPlayersCount, curMonolithLbVotesCount
from "%ui/ui_library.nut" import *

let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { currentMonolithLevel } = require("%ui/mainMenu/monolith/monolith_common.nut")
let { isMonolithMenuAvailable } = require("%ui/mainMenu/monolith/monolithMenu.nut")
let { playerBaseState } = require("%ui/profile/profileState.nut")

#allow-auto-freeze

function monolithProgress() {
  let { playersCountToRestartProgress = 0 } = playerBaseState.get()
  if (playersCountToRestartProgress == 0 || curMonolithLbVotesCount.get() == null)
    return static { watch = [playerBaseState, curMonolithLbData, curMonolithLbVotesCount]}
  let percent = curMonolithLbVotesCount.get() / playersCountToRestartProgress.tofloat() * 100

  return {
    watch  = static [playerBaseState, curMonolithLbData]
    size = FLEX_H
    flow = FLOW_VERTICAL
    gap = 6
    children = [
      static { hplace = ALIGN_CENTER text = loc("monolith/resetProgressShort", "Harmonization"), rendObj = ROBJ_TEXT fontSize = consoleTitleFontSize color = textColor}
      {
        rendObj = ROBJ_BOX
        size = static [flex(), 40]
        borderWidth = 2
        borderColor = textColor
        transform = static {}
        children = [
          {
            rendObj = ROBJ_SOLID
            size = [pw(percent), flex()]
            margin = static [2, 0, 2, 2]
            color = textColor
          }
          {
            rendObj = ROBJ_TEXT
            text = $"{curMonolithLbPlayersCount.get()}/{playersCountToRestartProgress}"
            fontFxColor = static Color(0,0,0,120)
            fontFx = FFT_BLUR
            fontFxFactor=8
            vplace = ALIGN_CENTER
            hplace = ALIGN_CENTER
            fontSize = consoleFontSize
            color = textColor
          }
        ]
      }
    ]
  }
}

let monolithTitle = static {rendObj = ROBJ_TEXT text = loc("monolith/name", "Monolith") fontSize = consoleTitleFontSize color = textColor hplace = ALIGN_RIGHT}

let mkMonolithNotification = @() Computed(getMonolithNotifications)

return {
  mkMonolithNotification
  mkMonolithPanel = function(canvasSize, data, notifier=null) {
    let notifications = mkMonolithNotification()
    return mkStdPanel(canvasSize, data, {
      children = [
        @() {
          watch = isMonolithMenuAvailable
          size = flex()
          children = !isMonolithMenuAvailable.get() ? null : [
            {
              size = flex()
              padding = static [8, 18]
              children = [
                @() {
                  size = flex()
                  watch = [notifications, isOnboarding],
                  children = (notifications.get() && !isOnboarding.get()) ? [
                    {rendObj = ROBJ_TEXT text = loc("monolith/console/upgrade_to_level", {level = currentMonolithLevel.get()+1}) hplace = ALIGN_CENTER vplace = ALIGN_CENTER color=textColor fontSize = consoleTitleFontSize}
                    flashingScreen("leaderboard_panel")
                  ] : null
                }
                function() {
                  let needFirstUpgrade = isOnboarding.get()
                  return {
                    flow = FLOW_VERTICAL
                    watch = static [isOnboarding]
                    padding = 8
                    size = static flex()
                    gap = 2
                    children = needFirstUpgrade
                      ? mkFlashingInviteTextScreen(loc("monolith/console/get_access"), "leaderboard_panel")
                      : [
                        monolithTitle
                        @() { watch = currentMonolithLevel children = currentMonolithLevel.get() < 10 ? null : monolithProgress size = FLEX_H}
                        @() {
                          watch = currentMonolithLevel
                          text = loc($"monolith/level" { level = currentMonolithLevel.get()})
                          color = textColor
                          rendObj = ROBJ_TEXT
                          fontSize = consoleTitleFontSize
                        }
                        static {size = flex()}
                        inviteText
                        waitingCursor
                    ]
                  }
                }
              ]
            }
          ]
        },
        notifier
      ]
    })
  }
}
