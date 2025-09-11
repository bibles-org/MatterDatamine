from "console" import register_command as console_register_command
from "dainput2" import set_actions_binding_column_active
from "eventbus" import eventbus_send, eventbus_subscribe
from "%ui/ui_library.nut" import gui_scene, mkWatched, Computed, Watched, log

let platform = require("%dngscripts/platform.nut")
let controlsTypes = require("%ui/control/controls_types.nut")
let forcedControlsType = mkWatched(persist, "forcedControlsType")
let defRaw = platform.is_pc ? 0 : 1
let lastActiveControlsTypeRaw = mkWatched(persist, "lastActiveControlsTypeRaw", defRaw)
let def = platform.is_pc
            ? controlsTypes.keyboardAndMouse
            : platform.is_sony
              ? controlsTypes.ds4gamepad
              : platform.is_nswitch
                ? controlsTypes.nxJoycon
                : controlsTypes.x1gamepad

let lastActiveControlsType = mkWatched(persist, "lastActiveControlType", def)

const EV_FORCE_CONTROLS_TYPE = "forced_controls_type"
function setForcedControlsType(v){
  forcedControlsType.set(v)
}

enum ControlsTypes {
  AUTO = 0
  KB_MOUSE = 1
  GAMEPAD = 2
}

console_register_command(@(value) eventbus_send(EV_FORCE_CONTROLS_TYPE, {val=value}), "ui.debugControlsType")
eventbus_subscribe(EV_FORCE_CONTROLS_TYPE, @(msg) setForcedControlsType(msg.val))

const EV_INPUT_USED = "input_dev_used"

function update_input_types(new_val){
  let map = {
    [1] = controlsTypes.keyboardAndMouse,
    [2] = controlsTypes.x1gamepad,
    
  }
  local ctype = map?[new_val] ?? def
  if (platform.is_sony && ctype==controlsTypes.x1gamepad)
    ctype = controlsTypes.ds4gamepad
  else if (platform.is_nswitch)
    ctype = controlsTypes.nxJoycon
  lastActiveControlsTypeRaw.set(new_val ?? defRaw)
  lastActiveControlsType.set(ctype)
}

forcedControlsType.subscribe_with_nasty_disregard_of_frp_update(function(val) {
  if (val)
    update_input_types(val)
})

eventbus_subscribe(EV_INPUT_USED, function(msg) {
  if ([null, 0].contains(forcedControlsType.get()))
    update_input_types(msg.val)
})

let isGamepad = Computed(@() forcedControlsType.get() == ControlsTypes.GAMEPAD || [
                                  controlsTypes.x1gamepad,
                                  controlsTypes.ds4gamepad,
                                  controlsTypes.nxJoycon
                                ].contains(lastActiveControlsType.get())
                            )
keepref(isGamepad)

const GAMEPAD_COLUMN = 1
let wasGamepad = mkWatched(persist, "wasGamepad", function() {
  let wasGamepadV = platform.is_pc ? false : true
  gui_scene.setConfigProps({gamepadCursorControl = wasGamepadV})
  return wasGamepadV
}())

let enabledGamepadControls = Watched(!platform.is_pc || isGamepad.get())

if (platform.is_pc){
  wasGamepad.subscribe_with_nasty_disregard_of_frp_update(@(v) enabledGamepadControls.set(v))
  let setGamePadActive = @(v) set_actions_binding_column_active(GAMEPAD_COLUMN, v && forcedControlsType.get() != ControlsTypes.KB_MOUSE)
  enabledGamepadControls.subscribe_with_nasty_disregard_of_frp_update(setGamePadActive)
  forcedControlsType.subscribe_with_nasty_disregard_of_frp_update(@(_v) setGamePadActive(enabledGamepadControls.get()))
  setGamePadActive(isGamepad.get())
}

isGamepad.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  wasGamepad.set(wasGamepad.get() || v)
  log($"isGamepad changed to = {v}")
  gui_scene.setConfigProps({gamepadCursorControl = v})
})


return freeze({
  controlsTypes
  lastActiveControlsType
  lastActiveControlsTypeRaw
  isGamepad
  wasGamepad
  enabledGamepadControls
  forcedControlsType
  ControlsTypes
  setForcedControlsType
})
