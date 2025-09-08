from "%ui/ui_library.nut" import *
from "math" import max
let { heroAmValue, heroAmMaxValue, isSyphoningAm } = require("%ui/hud/state/am_storage_state.nut")
let { activeMatterIcon } = require("%ui/mainMenu/currencyIcons.nut")
let { mkText } = require("%ui/components/commonComponents.nut")
let { itemHeight } = require("%ui/hud/menus/components/inventoryStyle.nut")
let { setTooltip } = require("%ui/components/cursors.nut")

let picProgress = Picture("ui/skin#round_border_2.svg:{0}:{0}:K".subst(itemHeight))
let progressbarBackgroundColor = Color(70, 70, 70, 120)
let amColor = Color(20, 220, 253)

let mkActiveMatterStorageWidget = @(value = null) function() {
  let storageAm = (value ?? heroAmValue.get()).tofloat()
  local percent = storageAm <= 0 ? 0 : storageAm / heroAmMaxValue.get().tofloat()
  percent = percent * 0.83 + 0.09 

  return {
    size = [itemHeight, itemHeight]
    watch = [heroAmValue, heroAmMaxValue, isSyphoningAm]
    padding = hdpx(1)
    behavior = Behaviors.Button
    onHover = @(on) setTooltip(on ? "{0}{1}".subst(
      loc("amStatus", {cur = storageAm, max = heroAmMaxValue.get()}),
      isSyphoningAm.get() ? "\n{0}".subst(loc("amSyphoningInProgress")) : "") : null)
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