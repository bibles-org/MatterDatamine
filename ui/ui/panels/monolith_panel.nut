from "%ui/ui_library.nut" import *

let { isOnboarding, onboardingMonolithFirstLevelUnlocked } = require("%ui/hud/state/onboarding_state.nut")
let { currentMonolithLevel } = require("%ui/mainMenu/monolith/monolith_common.nut")
let { isMonolithMenuAvailable, getMonolithNotifications } = require("%ui/mainMenu/monolith/monolithMenu.nut")
let { mkFlashingInviteTextScreen, flashingScreen, mkStdPanel, textColor, waitingCursor, inviteText, consoleFontSize, consoleTitleFontSize } = require("%ui/panels/console_common.nut")
let { playerBaseState } = require("%ui/profile/profileState.nut")
let { curLbData, curLbPlayersCount } = require("%ui/leaderboard/lb_state_base.nut")

function monolithProgress() {
  let { playersCountToRestartProgress = 0 } = playerBaseState.get()
  if (playersCountToRestartProgress == 0 || curLbPlayersCount.get() == null)
    return const { watch = [playerBaseState, curLbData]}
  let percent = curLbPlayersCount.get() / playersCountToRestartProgress.tofloat() * 100

  return {
    watch  = const [playerBaseState, curLbData]
    size = const [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = 6
    children = [
      const { hplace = ALIGN_CENTER text = loc("monolith/resetProgressShort", "Harmonization"), rendObj = ROBJ_TEXT fontSize = consoleTitleFontSize color = textColor}
      {
        rendObj = ROBJ_BOX
        size = const [flex(), 40]
        borderWidth = 2
        borderColor = textColor
        transform = const {}
        children = [
          {
            rendObj = ROBJ_SOLID
            size = [pw(percent), flex()]
            margin = const [2, 0, 2, 2]
            color = textColor
          }
          {
            rendObj = ROBJ_TEXT
            text = $"{curLbPlayersCount.get()}/{playersCountToRestartProgress}"
            fontFxColor = const Color(0,0,0,120)
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

let monolithTitle = const {rendObj = ROBJ_TEXT text = loc("monolith/name", "Monolith") fontSize = consoleTitleFontSize color = textColor hplace = ALIGN_RIGHT}

return {
  mkMonolithPanel = function(canvasSize, data) {
    let notifications = Computed(getMonolithNotifications)
    return mkStdPanel(canvasSize, data, {
      children = @() {
        watch = isMonolithMenuAvailable
        size = flex()
        children = !isMonolithMenuAvailable.get() ? null : [
          @() {
            size = flex()
            watch = const [notifications, isOnboarding],
            children = (notifications.get() && !isOnboarding.get()) ? [
              const {rendObj = ROBJ_TEXT text = $"UPGRADE NOW TO LEVEL:  {currentMonolithLevel.get()+1}" hplace = ALIGN_CENTER vplace = ALIGN_CENTER color=textColor fontSize = consoleTitleFontSize}
              flashingScreen
            ] : null
          }
          function() {
            let needFirstUpgrade = isOnboarding.get() && !onboardingMonolithFirstLevelUnlocked.get()
            return {
              flow = FLOW_VERTICAL
              watch = const [isOnboarding, onboardingMonolithFirstLevelUnlocked]
              padding = 8
              size = const flex()
              gap = 2
              children = needFirstUpgrade
                ? const mkFlashingInviteTextScreen("Upgrade access level to Portal and Monoloth")
                : [
                  monolithTitle
                  @() { watch = currentMonolithLevel children = currentMonolithLevel.get() < 10 ? null : monolithProgress size = const [flex(), SIZE_TO_CONTENT]}
                  @() {
                    watch = currentMonolithLevel
                    text = loc($"monolith/level" { level = currentMonolithLevel.get()})
                    color = textColor
                    rendObj = ROBJ_TEXT
                    fontSize = consoleTitleFontSize
                  }
                  const {size = flex()}
                  inviteText
                  waitingCursor
              ]
            }
          }
        ]
      }
    })
  }
}
