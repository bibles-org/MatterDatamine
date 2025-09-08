from "%ui/ui_library.nut" import *

let { debounce } = require("%sqstd/timers.nut")
let colors = require("%ui/components/colors.nut")
let gamepadImgByKey = require("%ui/components/gamepadImgByKey.nut")
let active_controls = require("%ui/control/active_controls.nut")
let { addModalPopup, removeModalPopup } = require("%ui/components/modalPopupWnd.nut")
let JB = require("%ui/control/gui_buttons.nut")


function listItem(text, action) {
  let group = ElemGroup()
  let stateFlags = Watched(0)
  let height = calc_str_box("A")[1]
  let activeBtn = gamepadImgByKey.mkImageCompByDargKey(JB.A,
    { height = height, hplace = ALIGN_RIGHT, vplace = ALIGN_CENTER})
  return function() {
    let sf = stateFlags.value
    let hover = sf & S_HOVER
    return {
      behavior = [Behaviors.Button]
      clipChildren=true
      rendObj = ROBJ_SOLID
      color = hover ? colors.BtnBgHover : colors.BtnBgNormal
      size = [flex(), SIZE_TO_CONTENT]
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
          size=[flex(),SIZE_TO_CONTENT]
          speed = hdpx(100)
          text = text
          group = group
          color = (stateFlags.value & S_HOVER) ? colors.BtnTextHover : colors.BtnTextNormal
        }
        active_controls.isGamepad.value && hover ? activeBtn : null
      ]
    }
  }
}

function mkMenu(width, actions, uid) {
  let visibleActions = actions.filter(@(a) a?.isVisible.value ?? true)
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
  if (actions.findvalue(@(a) a?.isVisible.value ?? true) == null)
    return 

  uidCounter++
  let uid = $"contextMenu{uidCounter}"
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
