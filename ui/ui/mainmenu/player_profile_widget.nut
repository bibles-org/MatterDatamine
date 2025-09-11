from "%ui/hud/hud_menus_state.nut" import openMenu
from "%ui/components/cursors.nut" import setTooltip
from "%ui/components/commonComponents.nut" import mkText
from "%ui/ui_library.nut" import *
from "%ui/hud/menus/journal.nut" import JournalMenuId, journalCurrentTab
from "%ui/components/colors.nut" import CurrencyDefColor, CurrencyUseColor, InfoTextValueColor

let { isOnboarding } = require("%ui/hud/state/onboarding_state.nut")
let { isOnPlayerBase } = require("%ui/hud/state/gametype_state.nut")
let { showCursor } = require("%ui/cursorState.nut")
let { playerCurrentLevel, currentPlayerLevelNeedExp, currentPlayerLevelHasExp } = require("%ui/hud/menus/notes/player_progression.nut")

let levelLineExpColor = Color(186, 186, 186, 255)
let levelLineExpBackgroundColor = Color(0, 0, 0, 50)

let playerLevelExpLine = function() {
  let levelRatio = currentPlayerLevelHasExp.get().tofloat() / currentPlayerLevelNeedExp.get().tofloat()

  return {
    watch = static [ currentPlayerLevelHasExp, currentPlayerLevelNeedExp ]
    vplace = ALIGN_BOTTOM
    pos = [0, hdpx(4)]
    size = static [ flex(), hdpx(2) ]
    children = [
      static {
        rendObj = ROBJ_SOLID
        size = flex()
        color = levelLineExpBackgroundColor
      }
      {
        rendObj = ROBJ_SOLID
        size = [ pw(clamp(100, 0, levelRatio * 100)), flex() ]
        color = levelLineExpColor
      }
    ]
  }
}

function mkProfileWidget() {
  let stateFlags = Watched(0)
  return function() {
    if (isOnboarding.get() || !isOnPlayerBase.get())
      return static { watch = [isOnboarding, isOnPlayerBase] }
    return {
      children = [
        @() {
          flow = FLOW_HORIZONTAL
          hplace = ALIGN_CENTER
          onElemState = @(s) stateFlags.set(s)
          gap = hdpx(10)
          watch = [isOnboarding, isOnPlayerBase, showCursor, stateFlags]
          behavior = showCursor.get() ? Behaviors.Button : null
          skipDirPadNav = true
          onHover = @(on) setTooltip(on ? loc("profile/open") : null)
          onClick = function() {
            journalCurrentTab.set("player_progressio")
            openMenu(JournalMenuId)
          }
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
