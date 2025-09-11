from "%ui/mainMenu/currencyIcons.nut" import activeMatterIcon
from "%ui/components/commonComponents.nut" import mkText
from "%ui/hud/menus/components/inventoryStyle.nut" import itemHeight
from "%ui/components/cursors.nut" import setTooltip

from "%ui/ui_library.nut" import *
from "math" import max
let { heroAmValue, heroAmMaxValue } = require("%ui/hud/state/am_storage_state.nut")
let { isInBattleState } = require("%ui/state/appState.nut")

#allow-auto-freeze

let picProgress = Picture("ui/skin#round_border_2.svg:{0}:{0}:K".subst(itemHeight))
let progressbarBackgroundColor = Color(70, 70, 70, 120)
let amColor = Color(20, 220, 253)

let mkActiveMatterStorageWidget = @(value = null) function() {
  let storageAm = (value ?? heroAmValue.get()).tofloat()
  local percent = storageAm <= 0 ? 0 : storageAm / heroAmMaxValue.get().tofloat()
  percent = percent * 0.83 + 0.09 

  return {
    watch = [heroAmValue, heroAmMaxValue, isInBattleState]
    size = [itemHeight, itemHeight]
    padding = hdpx(1)
    skipDirPadNav = isInBattleState.get()
    behavior = Behaviors.Button
    onHover = @(on) setTooltip(on ?
      loc("amStatus", {cur = storageAm, max = heroAmMaxValue.get()})
      : null)
    children = [
      {
        size = flex()
        rendObj = ROBJ_PROGRESS_CIRCULAR
        image = picProgress
        fgColor = amColor
        bgColor = progressbarBackgroundColor
        fValue = percent
      }
      {
        vplace = ALIGN_CENTER
        hplace = ALIGN_CENTER
        children = activeMatterIcon(hdpx(40)).__update({ color = Color(170, 170, 170, 120) })
      }
      {
        vplace = ALIGN_TOP
        hplace = ALIGN_CENTER
        children = mkText(storageAm, { color = amColor, pos = [0, -hdpx(5)]})
      }
    ]
  }
}

return {
  mkActiveMatterStorageWidget
}