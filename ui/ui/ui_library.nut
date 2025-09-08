from "math" import min, max, clamp
from "%sqstd/frp.nut" import WatchedRo, WatchedImmediate

let { loc } = require("%dngscripts/localizations.nut")
let { register_command, command } = require("console")
let { defer } = require("dagor.workcycle")
let darg_library = require("%darg/darg_library.nut")
let { sh, sw } = require("daRg")

global enum Layers {
  Default
  Upper
  ComboPopup
  MsgBox
  Blocker
  Tooltip
  Inspector
}

let export = {
  loc
  console_register_command = register_command
  console_command = command
  defer
}

local hdpx = @(pixels) sh(100.0 * pixels / 1080)
local hdpxi = @(pixels) hdpx(pixels).tointeger()
local fsh = @(val) sh(val)

let defCoef = 1920.0 / 1080
let isWideScreen = sw(100).tofloat() / sh(100) > defCoef
if (!isWideScreen) {
  let curCoef = sw(100).tofloat() / sh(100)
  let delta = curCoef / defCoef
  hdpx = @(pixels) sh(100.0 * pixels * delta / 1080)
  hdpxi = @(pixels) hdpx(pixels).tointeger()
  fsh = @(val) sh(val * delta)
}

let AMLibrary = darg_library.__merge({
  hdpx
  hdpxi
  fsh
})

return export.__update(
  {min, max, clamp, WatchedRo, WatchedImmediate},
  require("daRg"),
  require("frp"),
  require("%sqGlob/library_logs.nut"),
  AMLibrary,
  require("%sqstd/functools.nut")
  {DngBhv = require("dng.behaviors")}
)
