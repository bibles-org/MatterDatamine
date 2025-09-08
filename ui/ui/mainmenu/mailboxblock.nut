from "%ui/ui_library.nut" import *

let { ModalBgTint, TextHighlight, ControlBg, Inactive } = require("%ui/components/colors.nut")
let {bigGap, gap} = require("%ui/viewConst.nut")
let { makeVertScrollExt } = require("%ui/components/scrollbar.nut")
let { fontIconButton, textButton, textButtonSmallStyle} = require("%ui/components/button.nut")
let { inbox, clearAll, markReadAll, hasUnread, isMailboxVisible, onNotifyRemove, onNotifyShow
} = require("%ui/mainMenu/mailboxState.nut")
let { addModalPopup, removeModalPopup } = require("%ui/components/modalPopupWnd.nut")

let MAILBOX_MODAL_UID = "mailbox_modal_wnd"
let wndWidth = hdpx(450)
let maxListHeight = hdpx(300)
let padding = gap










let mkRemoveBtn = @(notify) {
  size = SIZE_TO_CONTENT
  children = fontIconButton("trash-o", @() onNotifyRemove(notify))
}

let btnParams = textButtonSmallStyle.__merge({ margin = 0, size = [flex(), hdpx(30)], halign = ALIGN_LEFT })
let defaultStyle = btnParams

let item = @(notify) {
  size = [flex(), SIZE_TO_CONTENT]
  flow  = FLOW_HORIZONTAL
  gap = hdpx(2)
  children = [
    textButton(notify.text, @() onNotifyShow(notify), defaultStyle)
    mkRemoveBtn(notify)
  ]
}

let mailsPlaceHolder = {
  size = [flex(), SIZE_TO_CONTENT]
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
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER

  children = [
    {
      rendObj = ROBJ_TEXT
      text="{0} {1}".subst(loc("Notifications:"), total > 0 ? total : "")
      color = Inactive
      margin = [0, 0, 0, gap]
    }
    {size=[flex(),0]}
    {
      vplace = ALIGN_CENTER
     children = fontIconButton("icon_buttons/x_btn.svg", @() removeModalPopup(MAILBOX_MODAL_UID) )
    }
  ]
}

let clearAllBtn = fontIconButton("trash-o", clearAll, {hplace=ALIGN_RIGHT})

function mailboxBlock() {
  let elems = inbox.value.map(item)
  if (elems.len() == 0)
    elems.append(mailsPlaceHolder)
  elems.reverse()

  return {
    size = [wndWidth, SIZE_TO_CONTENT]
    watch = [hasUnread, inbox]
    flow = FLOW_VERTICAL
    gap = bigGap

    children = [
      mkHeader(inbox.value.len())
      makeVertScrollExt({
        size = [flex(), SIZE_TO_CONTENT]
        gap = gap
        flow = FLOW_VERTICAL
        children = elems
      },
      {
        size = [flex(), SIZE_TO_CONTENT]
        maxHeight = maxListHeight
        needReservePlace = false
      })
      clearAllBtn
    ]
  }
}

inbox.subscribe(function(v) { if (v.len() == 0) removeModalPopup(MAILBOX_MODAL_UID) })

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