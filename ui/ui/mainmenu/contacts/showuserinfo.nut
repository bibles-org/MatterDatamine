let { is_xbox, is_sony } = require("%dngscripts/platform.nut")
let {INVALID_USER_ID} = require("matching.errors")
let { consoleCompare } = require("%ui/helpers/platformUtils.nut")
let userInfo = require("%sqGlob/userInfo.nut")

let { eventbus_send } = require("eventbus")

local showUserInfo = @(userId) println($"[USER INFO] Try to open {userId} profile on wrong platform")
local canShowUserInfo = @(...) false

if (is_xbox) {
  showUserInfo = @(userId) eventbus_send("showXboxUserInfo", {userId})
  canShowUserInfo = @(userId, name) (userId ?? INVALID_USER_ID) != INVALID_USER_ID
    && userInfo.value?.userId != userId
    && consoleCompare.xbox.isFromPlatform(name)
}
else if (is_sony) {
  showUserInfo = @(userId) eventbus_send("showPsnUserInfo", {userId})
  canShowUserInfo = @(userId, name) (userId ?? INVALID_USER_ID) != INVALID_USER_ID
    && userInfo.value?.userId != userId
    && consoleCompare.psn.isFromPlatform(name)
}

return {
  showUserInfo
  canShowUserInfo
}