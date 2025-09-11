from "%dngscripts/platform.nut" import is_xbox, is_sony, is_pc, is_nswitch

from "%sqstd/string.nut" import endsWith, startsWith

from "%ui/state/crossnetwork_state.nut" import CrossplayState



let consoleCompare = freeze({
  xbox = {
    isFromPlatform = @(name) endsWith(name, "@live") || startsWith(name, "^")
    isPlatform = is_xbox
  }
  psn = {
    isFromPlatform = @(name) endsWith(name, "@psn") || startsWith(name, "*")
    isPlatform = is_sony
  }
})

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

return freeze({
  isPlayerSuitableForContactsList
  canInterractCrossPlatform
  consoleCompare
  canInterractCrossPlatformByCrossplay
})
