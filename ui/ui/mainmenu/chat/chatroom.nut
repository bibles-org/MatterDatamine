from "%ui/ui_library.nut" import *

let { sub_txt } = require("%ui/fonts_style.nut")
let {textInput} = require("%ui/components/textInput.nut")
let {makeVertScrollExt} = require("%ui/components/scrollbar.nut")
let { textButton } = require("%ui/components/button.nut")
let {chatLogs} = require("chatState.nut")
let {sendMessage} = require("chatApi.nut")
let {format_unixtime, get_local_unixtime} = require("dagor.time")
let { remap_nick } = require("%ui/helpers/remap_nick.nut")

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
    size = [flex(), SIZE_TO_CONTENT]
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
      size = [flex(), SIZE_TO_CONTENT]
      children = textInput(chatMessage, options)
    }
  }


  function chatInput() {
    return {
      flow = FLOW_HORIZONTAL
      size = [flex(), SIZE_TO_CONTENT]
      valign = ALIGN_BOTTOM
      gap = fsh(1)
      padding = [fsh(1), 0, 0, 0]

      children = [
        chatInputField
        {
          valign = ALIGN_BOTTOM
          size = [SIZE_TO_CONTENT, flex()]
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
      size = [flex(), SIZE_TO_CONTENT]
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
      borderWidth = [2, 0]
      padding = [2, 0]

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
