from "eventbus" import eventbus_subscribe
from "dainput2" import GAMEPAD_VENDOR_SONY, GAMEPAD_VENDOR_NINTENDO

from "%ui/ui_library.nut" import *

let { platformId } = require("%dngscripts/platform.nut")
let controlsTypes = require("%ui/control/controls_types.nut")
let gamepadTypeByPlatform = {
  nswitch = controlsTypes.nxJoycon
  ps4 = controlsTypes.ds4gamepad
  ps5 = controlsTypes.ds4gamepad
}
let defGamepadType = gamepadTypeByPlatform?[platformId] ?? controlsTypes.x1gamepad

let gamepadType = mkWatched(persist, "gamepadType", defGamepadType)

function setInput(msg){
  let {ctype} = msg
  gamepadType.set(ctype==GAMEPAD_VENDOR_SONY
                ? controlsTypes.ds4gamepad
                : ctype==GAMEPAD_VENDOR_NINTENDO
                  ? controlsTypes.nxJoycon
                  : controlsTypes.x1gamepad)
}
eventbus_subscribe("input_gamepad_type", setInput)
console_register_command(@(value) setInput({ctype=value}), "ui.changegamepad")

wlog(gamepadType, "ui.changegamepad-->")

return gamepadType