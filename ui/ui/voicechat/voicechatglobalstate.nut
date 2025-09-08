let {nestWatched} = require("%dngscripts/globalState.nut")
let {Watched} = require("frp")
let platform = require("%dngscripts/platform.nut")
let { get_setting_by_blk_path } = require("settings")

const FIRST_USE_CHAT_WARN = "voice/voiceChatShouldShowFirstWarning"
let voiceChatShouldShowFirstWarning = Watched(platform.is_android && (get_setting_by_blk_path(FIRST_USE_CHAT_WARN) ?? true))

function is_voice_chat_available() {
  let isAvailableByBlk = get_setting_by_blk_path("voiceChatAvailable") ?? true
  return isAvailableByBlk && (platform.is_pc || platform.is_sony || platform.is_nswitch || platform.is_xbox)
}
let voiceChatEnabled = nestWatched("voiceChatEnabled", is_voice_chat_available())
let voiceChatEnabledUpdate = @(v) voiceChatEnabled.set(v)
let voiceChatRestricted = nestWatched("voiceChatRestricted", false)
let voiceChatRestrictedUpdate = @(v) voiceChatRestricted.set(v)

return {
  voiceChatShouldShowFirstWarning,
  voiceChatEnabled, voiceChatEnabledUpdate,
  voiceChatRestricted, voiceChatRestrictedUpdate
}
