import "%ui/components/msgbox.nut" as msgbox

from "eventbus" import eventbus_subscribe
from "%ui/ui_library.nut" import *

let platform = require("%dngscripts/platform.nut")
let { isProductionCircuit } = require("%sqGlob/appInfo.nut")

let dbgMultiplayerPermissions = Watched(true)
local checkMultiplayerPermissions = function checkMultiplayerPermissionsImpl() { 
  if (dbgMultiplayerPermissions.get())
    return true
  else
    msgbox.showMsgbox({text = loc("No multiplayer permissions")})
}
console_register_command(function() {
  dbgMultiplayerPermissions.set(!dbgMultiplayerPermissions.get())
  console_print($"mutliplayer permissions set to: {dbgMultiplayerPermissions.get()}")
}, "feature.toggleMultiplayerPermissions")

if (platform.is_ps5) {
  let { hasPremium, requestPremiumStatusUpdate } = require("sony.user")
  eventbus_subscribe("psPlusSuggested", @(_) requestPremiumStatusUpdate(@(_) null))
  let { suggest_psplus } = require("sony.store")

  function suggestAndAllowPsnPremiumFeatures() {
    if (hasPremium() || isProductionCircuit.get()) 
      return true

    suggest_psplus("psPlusSuggested", {})
    return false
  }

  checkMultiplayerPermissions = suggestAndAllowPsnPremiumFeatures
}

return {
  checkMultiplayerPermissions
}