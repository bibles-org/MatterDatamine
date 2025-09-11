from "%ui/navState.nut" import addNavScene, removeNavScene
import "%ui/components/progressText.nut" as progressText
from "%ui/mainMenu/customGames/roomScreen.nut" import getRoomScreen
from "%ui/mainMenu/customGames/roomsList.nut" import getRoomsListScreen
from "%ui/components/button.nut" import fontIconButton

from "%ui/ui_library.nut" import *

let { safeAreaHorPadding, safeAreaVerPadding } = require("%ui/options/safeArea.nut")
let { roomIsLobby, room } = require("%ui/state/roomState.nut")
let { showCreateRoom } = require("%ui/mainMenu/customGames/showCreateRoom.nut")

let JB = require("%ui/control/gui_buttons.nut")

let customGamesContent = @() {
  watch = [room, roomIsLobby]
  size = flex()
  children = !room.get()
    ? getRoomsListScreen()
    : roomIsLobby.get()
      ? getRoomScreen()
      : progressText(loc("lobbyStatus/gameIsRunning"))
}
local customGamesScene = null

let close = @() removeNavScene(customGamesScene)
let closeBtnAction = @() showCreateRoom.get() ? showCreateRoom.set(false) : close()

let buttonParams = {
  hotkeys=[[$"^Esc | {JB.B}", {description=loc("mainmenu/btnClose")}]]
  skipDirPadNav = true
}


let closeBtn = {
  size = hdpx(30)
  hplace = ALIGN_RIGHT
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = fontIconButton("icon_buttons/x_btn.svg", closeBtnAction, buttonParams)
}

customGamesScene = @() {
  watch = [safeAreaHorPadding, safeAreaVerPadding, room]
  size = flex()
  padding = [safeAreaVerPadding.get()+sh(5), safeAreaHorPadding.get()+sh(5)]
  children = [
    customGamesContent
    room.get() ? null : closeBtn
  ]
}

return {
  customGamesScene,
  customGamesOpen = @() addNavScene(customGamesScene),
  customGamesClose = close,
}