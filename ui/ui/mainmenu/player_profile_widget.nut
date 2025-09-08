from "%ui/ui_library.nut" import *
from "%ui/components/colors.nut" import CurrencyDefColor, CurrencyUseColor, InfoTextValueColor

let { openMenu } = require("%ui/hud/hud_menus_state.nut")
let { setTooltip } = require("%ui/components/cursors.nut")
let { playerProfileExperience, playerExperienceToLevel } = require("%ui/profile/profileState.nut")
let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { PLAYER_PROFILE_ID } = require("%ui/hud/menus/player_profile.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")

let levelLineExpColor = Color(186, 186, 186, 255)
let levelLineExpBackgroundColor = Color(0, 0, 0, 50)

let playerCurrentLevel = Computed(function() {
  for (local i = 0; i < playerExperienceToLevel.get().len(); i++)
    if (playerProfileExperience.get() < playerExperienceToLevel.get()[i]) {
      return i
  }
  return 0
})

let currentPlayerLevelNeedExp = Computed(function() {
  let needExp = playerExperienceToLevel.get()?[playerCurrentLevel.get()] ?? 0
  let prevExp = playerExperienceToLevel.get()?[playerCurrentLevel.get()-1] ?? 0

  return needExp - prevExp
})

let currentPlayerLevelHasExp = Computed(function() {
  let prevExp = playerExperienceToLevel.get()?[playerCurrentLevel.get()-1] ?? 0
  return playerProfileExperience.get() - prevExp
})


let playerLevelExpLine = function() {
  let levelRatio = currentPlayerLevelHasExp.get().tofloat() / currentPlayerLevelNeedExp.get().tofloat()

  return {
    watch = const [ currentPlayerLevelHasExp, currentPlayerLevelNeedExp ]
    vplace = ALIGN_BOTTOM
    pos = [0, hdpx(4)]
    size = const [ flex(), hdpx(2) ]
    children = [
      const {
        rendObj = ROBJ_SOLID
        size = flex()
        color = levelLineExpBackgroundColor
      }
      {
        rendObj = ROBJ_SOLID
        size = [ pw(levelRatio * 100), flex() ]
        color = levelLineExpColor
      }
    ]
  }
}

function mkProfileWidget() {
  let stateFlags = Watched(0)
  return function() {
    if (isOnboarding.get() || !isOnPlayerBase.get())
      return const { watch = [isOnboarding, isOnPlayerBase] }
    return {
      children = [
        @() {
          flow = FLOW_HORIZONTAL
          hplace = ALIGN_CENTER
          onElemState = @(s) stateFlags.set(s)
          gap = hdpx(10)
          watch = const [isOnboarding, isOnPlayerBase, hudIsInteractive, stateFlags]
          behavior = hudIsInteractive.get() ? Behaviors.Button : null
          onHover = @(on) setTooltip(on ? loc("profile/open") : null)
          onClick = @() openMenu(PLAYER_PROFILE_ID)
          children = [
            mkText(loc("player_progression/currentLevel"), {color = stateFlags.get() & S_HOVER ? CurrencyUseColor : null})
            @() {
              watch = [playerCurrentLevel, stateFlags]
              valign = ALIGN_CENTER
              halign = ALIGN_CENTER
              children = mkText(playerCurrentLevel.get() + 1, {color = stateFlags.get() & S_HOVER ? CurrencyUseColor : InfoTextValueColor}),
            }
          ]
        }
        playerLevelExpLine
      ]
    }
  }
}


return { profileWidget = mkProfileWidget()}
