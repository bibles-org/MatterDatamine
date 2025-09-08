from "%ui/ui_library.nut" import *

let mkCameraFovOption = require("%ui/mainMenu/menus/options/camera_fov_option_common.nut")

let MIN_FOV = 50.0
let MAX_FOV = 120.0

let settings = {
  minVal = MIN_FOV
  maxVal = MAX_FOV
  defVal = 90.0
  unit = 0.01 / ((MAX_FOV - MIN_FOV) / 100.0)
}

return {
  cameraFovOption = mkCameraFovOption(loc("gameplay/camera_fov"), "camera_fov", settings)
}