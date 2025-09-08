from "%sqstd/frp.nut" import Computed, Watched, WatchedRo

let { is_xbox, is_sony } = require("%dngscripts/platform.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")
let { get_setting_by_blk_path } = require("settings")

let isCrossnetworkChatAvailable = true
let isCrossnetworkChatOptionNeeded = !is_xbox 
let isDebugCrossplay = false

enum CrossplayState {
  OFF = "off"
  CONSOLES = "consoles"
  ALL = "all"
}

let CrossPlayStateWeight = {
  [CrossplayState.OFF] = 0,
  [CrossplayState.CONSOLES] = 1,
  [CrossplayState.ALL] = 2
}

const savedCrossnetworkPlayId = "gameplay/crossnetworkPlay"
let savedCrossnetworkState = nestWatched("savedCrossnetworkState", get_setting_by_blk_path(savedCrossnetworkPlayId) ?? CrossplayState.ALL)
let savedCrossnetworkStateUpdate = @(v) savedCrossnetworkState.set(v)

const savedCrossnetworkChatId = "gameplay/crossnetworkChat"
let savedCrossnetworkChatState = nestWatched("savedCrossnetworkChatState", get_setting_by_blk_path(savedCrossnetworkChatId) ?? true)
let savedCrossnetworkChatStateUpdate = @(v) savedCrossnetworkChatState.set(v)
let xboxCrossplayAvailable = nestWatched("xboxCrossplayAvailable", false)
let xboxCrossplayAvailableUpdate = @(v) xboxCrossplayAvailable.set(v)
let xboxCrosschatAvailable = nestWatched("xboxCrosschatAvailable", false)
let xboxCrosschatAvailableUpdate = @(v) xboxCrosschatAvailable.set(v)
let xboxMultiplayerAvailable = nestWatched("xboxMultiplayerAvailable", true)
let xboxMultiplayerAvailableUpdate = @(v) xboxMultiplayerAvailable.set(v)

let xboxCrossChatWithFriendsAllowed = nestWatched("xboxCrossChatWithFriendsAllowed", true)
let xboxCrossChatWithFriendsAllowedUpdate = @(v) xboxCrossChatWithFriendsAllowed.set(v)
let xboxCrossChatWithAllAllowed = nestWatched("xboxCrossChatWithAllAllowed", true)
let xboxCrossChatWithAllAllowedUpdate = @(v) xboxCrossChatWithAllAllowed.set(v)
let xboxCrossVoiceWithFriendsAllowed = nestWatched("xboxCrossVoiceWithFriendsAllowed", true)
let xboxCrossVoiceWithFriendsAllowedUpdate = @(v) xboxCrossVoiceWithFriendsAllowed.set(v)
let xboxCrossVoiceWithAllAllowed = nestWatched("xboxCrossVoiceWithAllAllowed", true)
let xboxCrossVoiceWithAllAllowedUpdate = @(v) xboxCrossVoiceWithAllAllowed.set(v)

let crossplayOptionNeededByProject = is_xbox || is_sony
let isCrossplayOptConsolesOnlyRequired = Watched(true)
let isCrossplayOptionNeeded = Watched(crossplayOptionNeededByProject || isDebugCrossplay)

let availableCrossplayOptions = Computed(function() {
  if (is_xbox) 
    return !xboxCrossplayAvailable.value ? [ CrossplayState.OFF ]
      : isCrossplayOptConsolesOnlyRequired.value ? [ CrossplayState.CONSOLES, CrossplayState.ALL ]
      : [ CrossplayState.ALL ]

  if (!isCrossplayOptionNeeded.value) 
    return [ CrossplayState.ALL ]

  if (!isCrossplayOptConsolesOnlyRequired.value) 
    return [ CrossplayState.OFF, CrossplayState.ALL ]

  return [ CrossplayState.OFF, CrossplayState.CONSOLES, CrossplayState.ALL ]
})

let validateCsState = @(state, available) available.contains(state) ? state : available?.top() ?? CrossplayState.ALL

let multiplayerAvailable = Computed(@() xboxMultiplayerAvailable.value)
local crossnetworkPlay = null
local crossnetworkChat = null

if (is_xbox) {
  crossnetworkPlay = Computed(@() xboxCrossplayAvailable.value
    ? validateCsState(savedCrossnetworkState.value, availableCrossplayOptions.value)
    : CrossplayState.OFF)

  crossnetworkChat = Computed(@() xboxCrosschatAvailable.value)
}
else if (is_sony || isDebugCrossplay) {
  crossnetworkPlay = Computed(@() validateCsState(savedCrossnetworkState.value, availableCrossplayOptions.value))
  crossnetworkChat = Computed(@() savedCrossnetworkChatState.value ?? false)
}
else {
  crossnetworkPlay = WatchedRo(CrossplayState.ALL)
  crossnetworkChat = WatchedRo(isCrossnetworkChatAvailable)
}

let isCrossnetworkIntercationAvailable = Computed(@()
  isCrossnetworkChatAvailable
  && multiplayerAvailable.value
  && crossnetworkChat.value)

let canCrossnetworkChatWithAll = Computed(@()
  isCrossnetworkIntercationAvailable.value
  && xboxCrossChatWithAllAllowed.value)

let canCrossnetworkChatWithFriends = Computed(@()
  isCrossnetworkIntercationAvailable.value
  && xboxCrossChatWithFriendsAllowed.value)

let canCrossnetworkVoiceWithAll = Computed(@()
  isCrossnetworkIntercationAvailable.value
  && xboxCrossVoiceWithAllAllowed.value)

let canCrossnetworkVoiceWithFriends = Computed(@()
  isCrossnetworkIntercationAvailable.value
  && xboxCrossVoiceWithFriendsAllowed.value)

return {
  savedCrossnetworkPlayId
  savedCrossnetworkState, savedCrossnetworkStateUpdate
  xboxCrossplayAvailable, xboxCrossplayAvailableUpdate
  crossnetworkPlay
  needShowCrossnetworkPlayIcon = is_xbox
  CrossplayState
  xboxCrosschatAvailable, xboxCrosschatAvailableUpdate
  crossnetworkChat
  savedCrossnetworkChatId
  savedCrossnetworkChatState, savedCrossnetworkChatStateUpdate
  CrossPlayStateWeight
  isCrossnetworkChatAvailable
  availableCrossplayOptions
  isCrossplayOptionNeeded
  isCrossnetworkChatOptionNeeded
  xboxMultiplayerAvailable, xboxMultiplayerAvailableUpdate
  multiplayerAvailable
  xboxCrossChatWithFriendsAllowed, xboxCrossChatWithFriendsAllowedUpdate,
  xboxCrossChatWithAllAllowed, xboxCrossChatWithAllAllowedUpdate,
  xboxCrossVoiceWithFriendsAllowed, xboxCrossVoiceWithFriendsAllowedUpdate,
  xboxCrossVoiceWithAllAllowed, xboxCrossVoiceWithAllAllowedUpdate,
  canCrossnetworkChatWithAll
  canCrossnetworkChatWithFriends
  canCrossnetworkVoiceWithAll
  canCrossnetworkVoiceWithFriends
}