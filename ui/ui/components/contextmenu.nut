from "%sqstd/timers.nut" import debounce

import "%ui/components/gamepadImgByKey.nut" as gamepadImgByKey

import "%ui/components/colors.nut" as colors
from "%ui/components/modalPopupWnd.nut" import addModalPopup, removeModalPopup

from "%ui/ui_library.nut" import *

let active_controls = require("%ui/control/active_controls.nut")
let JB = require("%ui/control/gui_buttons.nut")

#allow-auto-freeze

function listItem(text, action) {
  let group = ElemGroup()
  let stateFlags = Watched(0)
  let height = calc_str_box("A")[1]
  let activeBtn = gamepadImgByKey.mkImageCompByDargKey(JB.A,
    { height = height, hplace = ALIGN_RIGHT, vplace = ALIGN_CENTER})
  return function() {
    let sf = stateFlags.get()
    let hover = sf & S_HOVER
    return {
      behavior = [Behaviors.Button]
      clipChildren=true
      rendObj = ROBJ_SOLID
      color = hover ? colors.BtnBgHover : colors.BtnBgNormal
      size = FLEX_H
      group = group
      watch = [stateFlags, active_controls.isGamepad]
      padding = fsh(0.5)
      onClick = action
      onElemState = @(nsf) stateFlags.set(nsf)

      sound = {
        click  = "ui_sounds/button_click"
        hover  = "ui_sounds/menu_highlight"
        active = "ui_sounds/button_action"
      }

      children = [
        {
          rendObj = ROBJ_TEXT
          behavior = [Behaviors.Marquee]
          scrollOnHover=true
          size=FLEX_H
          speed = hdpx(100)
          text = text
          group = group
          color = (stateFlags.get() & S_HOVER) ? colors.BtnTextHover : colors.BtnTextNormal
        }
        active_controls.isGamepad.get() && hover ? activeBtn : null
      ]
    }
  }
}

function mkMenu(width, actions, uid) {
  let visibleActions = actions.filter(@(a) a?.isVisible.get() ?? true)
  let autoHide = debounce(@() removeModalPopup(uid), 0.01)
  return function() {
    if (visibleActions.len() == 0)
      autoHide() 

    return {
      watch = actions.map(@(a) a?.isVisible).filter(@(w) w != null)
      size = [width, SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      children = visibleActions.map(@(item) listItem(item.text,
        function() {
          item.action()
          removeModalPopup(uid)
        }))
    }
  }
}

local uidCounter = 0
return function(x, y, width, actions, cb = null) {
  if (actions.findvalue(@(a) a?.isVisible.get() ?? true) == null)
    return 

  uidCounter++
  let uid = $"contextMenu{uidCounter}"
  #forbid-auto-freeze
  return addModalPopup([x, y], {
    uid
    popupHalign = ALIGN_LEFT
    popupValign = y > sh(75) ? ALIGN_BOTTOM : ALIGN_TOP
    popupFlow = FLOW_VERTICAL
    moveDuraton = min(0.12 + 0.03 * actions.len(), 0.3) 
    onDetach = cb
    children = mkMenu(width, actions, uid)
  })
}
