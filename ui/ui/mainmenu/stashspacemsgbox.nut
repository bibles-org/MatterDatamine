
from "%ui/ui_library.nut" import *

let { mkTextArea } = require("%ui/components/commonComponents.nut")
let { body_txt } = require("%ui/fonts_style.nut")
let { showMessageWithContent } = require("%ui/components/msgbox.nut")
let { eventbus_send } = require("eventbus")

function showNoEnoughStashSpaceMsgbox(space) {
  showMessageWithContent({
    content={
      size = [sw(40), sh(30)]
      children = mkTextArea(loc("needMoreSpaceMsgBox", { needMore=space/10.0 }), { halign = ALIGN_CENTER, vplace = ALIGN_CENTER }.__update(body_txt))
    }
    buttons = [
      { text = loc("Ok"), isCurrent = true, action = @() null }
      { text = loc("console/press_to_recycler"), isCurrent = false, action = @() eventbus_send("hud_menus.open", const { id = "Am_clean" }) }
    ]
  })
}

return {
  showNoEnoughStashSpaceMsgbox
}