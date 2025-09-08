from "%ui/ui_library.nut" import *

let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")
let { hasModalWindows } = require("%ui/components/modalWindows.nut")
let { hasMsgBoxes } = require("%ui/components/msgbox.nut")
let { showSettingsMenu } = require("%ui/mainMenu/menus/settings_menu.nut")
let { showControlsMenu } = require("%ui/mainMenu/menus/controls_setup.nut")
let { isLoggedIn } = require("%ui/login/login_state.nut")
let { get_setting_by_blk_path } = require("settings")
let { doesNavSceneExist, navScenesListGen } = require("%ui/navState.nut")
let { freeCameraState } = require("%ui/freecamstate.nut")
let { isCurrentMenuInteractive } = require("%ui/hud/hud_menus_state.nut")

let showCursor = Computed(@()
  !freeCameraState.get() && (
  hudIsInteractive.get() || hasModalWindows.get() || hasMsgBoxes.get() || showSettingsMenu.get() ||
  showControlsMenu.get() || (!isLoggedIn.get() && !(get_setting_by_blk_path("disableMenu") ?? false)) ||
  isCurrentMenuInteractive.get() ||
  doesNavSceneExist(navScenesListGen.get()))
)

return {
  showCursor
}