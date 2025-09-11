from "%ui/fonts_style.nut" import sub_txt
from "%ui/components/textInput.nut" import textInput
from "%ui/components/scrollbar.nut" import makeVertScrollExt
from "%ui/components/button.nut" import textButton
from "%ui/mainMenu/chat/chatApi.nut" import sendMessage
from "dagor.time" import format_unixtime, get_local_unixtime
from "%ui/helpers/remap_nick.nut" import remap_nick

from "%ui/ui_library.nut" import *

let { chatLogs } = require("%ui/mainMenu/chat/chatState.nut")

let ColorInactive = Color(120,120,120)
function messageInLog(entry) {
  let fmtString = "%H:%M:%S"
  let {sender={name = "????"}, text="????"} = entry
  let timestamp = entry?.timestamp ?? get_local_unixtime()
  return {
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    text = "".concat(
      "<color=#616675>", format_unixtime(fmtString, timestamp), "  ",
      remap_nick(sender.name), "</color>",
      ": ", text
    )
    key = timestamp
    margin = fsh(0.5)
    size = FLEX_H
  }.__update(sub_txt)
}


function chatRoom(chatId) {
  if (chatId == null)
    return null

  let chatLogWatch = Computed(@() chatLogs.get()?[chatId])
  let chatMessage = Watched("")


  let scrollHandler = ScrollHandler()


  function doSendMessage() {
    if (chatMessage.get()=="")
      return
    sendMessage(chatId, chatMessage.get())
    chatMessage.set("")
  }


  function chatInputField() {
    let options = {
      placeholder = loc("chat/inputPlaceholder")
      margin = 0
      onReturn = doSendMessage
    }.__update(sub_txt)
    return {
      size = FLEX_H
      children = textInput(chatMessage, options)
    }
  }


  function chatInput() {
    return {
      flow = FLOW_HORIZONTAL
      size = FLEX_H
      valign = ALIGN_BOTTOM
      gap = fsh(1)
      padding = static [fsh(1), 0, 0, 0]

      children = [
        chatInputField
        {
          valign = ALIGN_BOTTOM
          size = FLEX_V
          halign = ALIGN_RIGHT
          children = textButton(loc("chat/sendBtn"), doSendMessage, {margin=0}.__update(sub_txt))
        }
      ]
    }
  }

  local lastScrolledTo = null

  function logContent() {
    if (chatLogWatch.get() == null)
      return {watch = chatLogWatch}
    let messages = chatLogWatch.get().map(messageInLog)
    let scrollTo = chatLogWatch.get().len() ? chatLogWatch.get().top()?.timestamp : null

    return {
      size = FLEX_H
      flow = FLOW_VERTICAL
      behavior = Behaviors.RecalcHandler

      watch = chatLogWatch

      children = messages

      onRecalcLayout = function(_initial) {
        if (scrollTo && scrollTo != lastScrolledTo) {
          lastScrolledTo = scrollTo
          scrollHandler.scrollToChildren(@(desc) ("key" in desc) && (desc.key == scrollTo), 2, false, true)
        }
      }
    }
  }


  function chatLog() {
    return {
      size = flex()

      rendObj = ROBJ_FRAME
      color = ColorInactive
      borderWidth = static [2, 0]
      padding = static [2, 0]

      children = makeVertScrollExt(logContent, {scrollHandler})
    }
  }
  let isChat = Computed(@() !!chatLogWatch.get())
  return function () {
    if (!isChat.get())
      return {watch = isChat}
    return {
      size = flex()
      flow = FLOW_VERTICAL
      stopMouse = true
      watch = isChat

      children = [
        chatLog
        chatInput
      ]
    }
  }
}


return chatRoom
