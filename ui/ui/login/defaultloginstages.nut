from "%ui/ui_library.nut" import *

let platform = require("%dngscripts/platform.nut")
let { disableRemoteNetServices } = require("%sqGlob/offline_mode.nut")

return disableRemoteNetServices ? require("chains/login_pc.nut")
  : platform.is_xbox ? require("chains/login_xbox.nut")
  : platform.is_sony ? require("chains/login_sony.nut")
  : require("chains/login_pc.nut")
