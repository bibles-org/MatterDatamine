from "%ui/ui_library.nut" import *

let platform = require("%dngscripts/platform.nut")
let {isProductionCircuit} = require("%sqGlob/appInfo.nut")
let msgbox = require("%ui/components/msgbox.nut")
let { eventbus_subscribe } = require("eventbus")

let dbgMultiplayerPermissions = Watched(true)
local checkMultiplayerPermissions = function checkMultiplayerPermissionsImpl() { 
  if (dbgMultiplayerPermissions.value)
    return true
  else
    msgbox.showMsgbox({text = loc("No multiplayer permissions")})
}
console_register_command(function() {
  dbgMultiplayerPermissions(!dbgMultiplayerPermissions.value)
  console_print($"mutliplayer permissions set to: {dbgMultiplayerPermissions.value}")
}, "feature.toggleMultiplayerPermissions")

if (platform.is_ps5) {
  let { hasPremium, requestPremiumStatusUpdate } = require("sony.user")
  eventbus_subscribe("psPlusSuggested", @(_) requestPremiumStatusUpdate(@(_) null))
  let { suggest_psplus } = require("sony.store")

  function suggestAndAllowPsnPremiumFeatures() {
    if (hasPremium() || isProductionCircuit.value) 
      return true

    suggest_psplus("psPlusSuggested", {})
    return false
  }

  checkMultiplayerPermissions = suggestAndAllowPsnPremiumFeatures
}

return {
  checkMultiplayerPermissions
}