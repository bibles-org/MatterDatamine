from "console" import register_command, command
from "dagor.workcycle" import defer

import "%darg/darg_library.nut" as darg_library
from "math" import min, max, clamp
from "%sqstd/frp.nut" import WatchedRo, WatchedImmediate
from "%dngscripts/localizations.nut" import loc
from "daRg" import sh, sw


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

local hdpx = @[pure](pixels) sh(100.0 * pixels / 1080)
local hdpxi = @[pure](pixels) hdpx(pixels).tointeger()
local fsh = @[pure](val) sh(val)

let defCoef = 1920.0 / 1080
let isWideScreen = sw(100).tofloat() / sh(100) > defCoef
if (!isWideScreen) {
  let curCoef = sw(100).tofloat() / sh(100)
  let delta = curCoef / defCoef
  hdpx = @[pure](pixels) sh(100.0 * pixels * delta / 1080)
  hdpxi = @[pure](pixels) hdpx(pixels).tointeger()
  fsh = @[pure](val) sh(val * delta)
}

let AMLibrary = darg_library.__merge({
  hdpx
  hdpxi
  fsh
})

return freeze(export.__update(
  {min, max, clamp, WatchedRo, WatchedImmediate},
  require("daRg"),
  require("frp"),
  require("%sqGlob/library_logs.nut"),
  AMLibrary,
  require("%sqstd/functools.nut")
  {DngBhv = require("dng.behaviors")}
))
