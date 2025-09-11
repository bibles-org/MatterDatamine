from "%ui/components/commonComponents.nut" import mkTextArea
from "%ui/fonts_style.nut" import body_txt
from "%ui/components/msgbox.nut" import showMessageWithContent
from "eventbus" import eventbus_send


from "%ui/ui_library.nut" import *


function showNoEnoughStashSpaceMsgbox(space) {
  showMessageWithContent({
    content={
      size = static [sw(40), sh(30)]
      children = mkTextArea(loc("needMoreSpaceMsgBox", { needMore=space }), { halign = ALIGN_CENTER, vplace = ALIGN_CENTER }.__update(body_txt))
    }
    buttons = [
      { text = loc("Ok"), isCurrent = true, action = @() null }
      { text = loc("console/press_to_recycler"), isCurrent = false, action = @() eventbus_send("hud_menus.open", static { id = "Am_clean" }) }
    ]
  })
}

return {
  showNoEnoughStashSpaceMsgbox
}