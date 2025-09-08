from "%ui/ui_library.nut" import *

let { safeAreaHorPadding, safeAreaVerPadding } = require("%ui/options/safeArea.nut")
let {addNavScene, removeNavScene} = require("%ui/navState.nut")
let {roomIsLobby, room} = require("%ui/state/roomState.nut")
let {showCreateRoom} = require("showCreateRoom.nut")

let progressText = require("%ui/components/progressText.nut")
let {getRoomScreen} = require("roomScreen.nut")
let {getRoomsListScreen} = require("roomsList.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { fontIconButton } = require("%ui/components/button.nut")

let customGamesContent = @() {
  watch = [room, roomIsLobby]
  size = flex()
  children = !room.get()
    ? getRoomsListScreen()
    : roomIsLobby.get()
      ? getRoomScreen()
      : progressText(loc("lobbyStatus/gameIsRunning"))
}

let isCustomGamesOpened = mkWatched(persist, "isCustomGamesOpened", false)
let close = @() isCustomGamesOpened.set(false)
let closeBtnAction = @() showCreateRoom.get() ? showCreateRoom.set(false) : close()

let buttonParams = {
  hotkeys=[[$"^Esc | {JB.B}", {description=loc("mainmenu/btnClose")}]]
  skipDirPadNav = true
}


let closeBtn = {
  size = [hdpx(30), hdpx(30)]
  hplace = ALIGN_RIGHT
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = fontIconButton("icon_buttons/x_btn.svg", closeBtnAction, buttonParams)
}

let customGamesScene = @() {
  watch = [safeAreaHorPadding, safeAreaVerPadding, room]
  size = flex()
  onDetach = @() isCustomGamesOpened.set(false)
  padding = [safeAreaVerPadding.get()+sh(5), safeAreaHorPadding.get()+sh(5)]
  children = [
    customGamesContent
    room.get() ? null : closeBtn
  ]
}

if (isCustomGamesOpened.get())
  addNavScene(customGamesScene)
isCustomGamesOpened.subscribe(@(val) val
  ? addNavScene(customGamesScene)
  : removeNavScene(customGamesScene))


return {
  customGamesScene,
  customGamesOpen = @() isCustomGamesOpened(true),
  customGamesClose = close,
  isCustomGamesOpened
}