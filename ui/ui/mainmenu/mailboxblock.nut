from "%ui/components/button.nut" import textButtonSmallStyle

from "%ui/mainMenu/mailboxState.nut" import clearAll, markReadAll, onNotifyRemove, onNotifyShow

from "%ui/components/colors.nut" import ModalBgTint, TextHighlight, ControlBg, Inactive
from "%ui/viewConst.nut" import bigGap, gap
from "%ui/components/scrollbar.nut" import makeVertScrollExt
from "%ui/components/button.nut" import fontIconButton, textButton
from "%ui/components/modalPopupWnd.nut" import addModalPopup, removeModalPopup

from "%ui/ui_library.nut" import *

let { inbox, hasUnread, isMailboxVisible, MAILBOX_MODAL_UID } = require("%ui/mainMenu/mailboxState.nut")

let wndWidth = hdpx(450)
let maxListHeight = hdpx(300)
let padding = gap










let mkRemoveBtn = @(notify) {
  size = SIZE_TO_CONTENT
  children = fontIconButton("trash-o", @() onNotifyRemove(notify))
}

let btnParams = textButtonSmallStyle.__merge({ margin = 0, size = static [flex(), hdpx(30)], halign = ALIGN_LEFT })
let defaultStyle = btnParams

let item = @(notify) {
  size = FLEX_H
  flow  = FLOW_HORIZONTAL
  gap = hdpx(2)
  children = [
    textButton(notify.text, @() onNotifyShow(notify), defaultStyle)
    mkRemoveBtn(notify)
  ]
}

let mailsPlaceHolder = {
  size = FLEX_H
  rendObj = ROBJ_SOLID
  padding
  color = ControlBg
  children = {
    rendObj = ROBJ_TEXT
    color = TextHighlight
    text = loc("no notifications")
  }
}

let mkHeader = @(total) {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER

  children = [
    {
      rendObj = ROBJ_TEXT
      text="{0} {1}".subst(loc("Notifications:"), total > 0 ? total : "")
      color = Inactive
      margin = [0, 0, 0, gap]
    }
    {size=static [flex(),0]}
    {
      vplace = ALIGN_CENTER
      children = fontIconButton("icon_buttons/x_btn.svg", @() removeModalPopup(MAILBOX_MODAL_UID) )
    }
  ]
}

let clearAllBtn = fontIconButton("trash-o", clearAll, {hplace=ALIGN_RIGHT})

function mailboxBlock() {
  let elems = inbox.get().map(item)
  if (elems.len() == 0)
    elems.append(mailsPlaceHolder)
  elems.reverse()

  return {
    size = [wndWidth, SIZE_TO_CONTENT]
    watch = [hasUnread, inbox]
    flow = FLOW_VERTICAL
    gap = bigGap

    children = [
      mkHeader(inbox.get().len())
      makeVertScrollExt({
        size = FLEX_H
        gap = gap
        flow = FLOW_VERTICAL
        children = elems
      },
      {
        size = FLEX_H
        maxHeight = maxListHeight
        needReservePlace = false
      })
      clearAllBtn
    ]
  }
}

return @(event) addModalPopup(event.targetRect,
  {
    watch = inbox 
    uid = MAILBOX_MODAL_UID
    onAttach = function() {
      markReadAll()
      isMailboxVisible.set(true)
    }
    onDetach = function() {
      markReadAll()
      isMailboxVisible.set(false)
    }

    rendObj = ROBJ_BOX
    fillColor = Color(50,50,50)
    popupBg = { rendObj = ROBJ_WORLD_BLUR_PANEL, fillColor = ModalBgTint }

    children = mailboxBlock
  })