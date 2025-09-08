from "%ui/ui_library.nut" import *

let { squadSharedData } = require("squadState.nut")
let {addNavScene, removeNavScene} = require("%ui/navState.nut")
let chatRoom = require("%ui/mainMenu/chat/chatRoom.nut")

let openSquadChat = Watched(false)

function chatPanel() {
  return {
    size = [sw(50), sh(60)]
    hplace = ALIGN_CENTER
    watch = squadSharedData.squadChat
    children = chatRoom(squadSharedData.squadChat.value?.chatId)
  }
}

let chatRoot = {
  size = flex()
  rendObj = ROBJ_WORLD_BLUR_PANEL
  color = Color(150,150,150,255)
  children = chatPanel
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  hotkeys = [
    ["^J:Y | J:Start | Esc | Space", {action=@() openSquadChat(false), description = loc("mainmenu/btnClose")}]
  ]
}

openSquadChat.subscribe(
  function(val) {
    if (val)
      addNavScene(chatRoot)
    else
      removeNavScene(chatRoot)
  })

let {squadChat} = squadSharedData

return {
  openSquadChat = @() openSquadChat(true)
  squadChatExists = Computed(@() squadChat.value?.chatId != null)
}
