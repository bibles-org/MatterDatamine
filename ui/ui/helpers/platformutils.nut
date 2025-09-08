let { is_xbox, is_sony, is_pc, is_nswitch } = require("%dngscripts/platform.nut")
let { endsWith, startsWith } = require("%sqstd/string.nut")
let { CrossplayState } = require("%ui/state/crossnetwork_state.nut")


let consoleCompare = {
  xbox = {
    isFromPlatform = @(name) endsWith(name, "@live") || startsWith(name, "^")
    isPlatform = is_xbox
  }
  psn = {
    isFromPlatform = @(name) endsWith(name, "@psn") || startsWith(name, "*")
    isPlatform = is_sony
  }
}

function isPlayerSuitableForContactsList(name, crossnetworkChatValue) {
  if (crossnetworkChatValue)
    return true

  foreach (p in consoleCompare)
    if (p.isFromPlatform(name))
      return false
  return true
}

let canInterractCrossPlatform = function(name, crossnetworkChatValue) {
  if (crossnetworkChatValue)
    return true

  foreach (p in consoleCompare)
    if (p.isFromPlatform(name))
      return p.isPlatform

  return is_pc || is_nswitch 
}

function canInterractCrossPlatformByCrossplay(name, crossplayValue) {
  if (crossplayValue == CrossplayState.ALL)
    return true

  if (crossplayValue == CrossplayState.OFF)
    return canInterractCrossPlatform(name, false)

  
  foreach (p in consoleCompare)
    if (p.isFromPlatform(name))
      return true

  return false
}

return {
  isPlayerSuitableForContactsList
  canInterractCrossPlatform
  consoleCompare
  canInterractCrossPlatformByCrossplay
}
