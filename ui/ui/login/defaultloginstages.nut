from "%sqGlob/offline_mode.nut" import disableRemoteNetServices

from "%ui/ui_library.nut" import *

let platform = require("%dngscripts/platform.nut")

return disableRemoteNetServices ? require("%ui/login/chains/login_pc.nut")
  : platform.is_xbox ? require("%ui/login/chains/login_xbox.nut")
  : platform.is_sony ? require("%ui/login/chains/login_sony.nut")
  : require("%ui/login/chains/login_pc.nut")
