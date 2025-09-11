from "base64" import encodeString, decodeString
from "%ui/ui_library.nut" import *

let logP = require("%sqGlob/library_logs.nut").with_prefix("[PSNSESSION] ")
let { send, sessionManager } = require("%sonyLib/webApi.nut")
let { createPushContext } = require("%sonyLib/notifications.nut")
let supportedPlatforms = require("%ui/sony/supportedPlatforms.nut")
let { uid2console } = require("%ui/mainMenu/contacts/consoleUidsRemap.nut")

let createSessionData = @(pushContextId, name, customData1) {
  playerSessions = [{
    supportedPlatforms = supportedPlatforms.get()
    maxPlayers = 4
    maxSpectators = 0
    joinDisabled = false
    member = {
      players = [{
        accountId = "me"
        platform = "me"
        pushContexts = [{ pushContextId }]
      }]
    }
    localizedSessionName = {
      defaultLanguage = "en-US"
      localizedText = {["en-US"] = name }
    }
    joinableUserType = "NO_ONE"
    invitableUserType = "LEADER"
    exclusiveLeaderPrivileges = [
      "KICK"
      "UPDATE_JOINABLE_USER_TYPE"
      "UPDATE_INVITABLE_USER_TYPE"
    ]
    swapSupported = false
    customData1
  }]
}

let createPlayerData = @(pushContextId) {
  players = [ { accountId = "me", platform = "me", pushContexts = [{pushContextId}] } ]
}

local currentContextId = null
local currentSessionId = null


function createSession(squadId, on_success) {
  
  currentContextId = createPushContext()
  logP($"create with {currentContextId}")
  let desc = createSessionData(currentContextId, loc("title/name"), encodeString(squadId.tostring()))
  send(sessionManager.create(desc),
       function(r, e) {
         currentSessionId = r?.playerSessions?[0]?.sessionId
         if (e == null)
           on_success()
       })
}

function changeLeader(leaderUid) {
  let accountId = uid2console.get()?[leaderUid.tostring()]
  logP($"change leader of {currentSessionId} to {accountId}/{leaderUid}")
  if (currentSessionId && accountId)
    send(sessionManager.changeLeader(currentSessionId, accountId, "PS5"))
}

function invite(uid, on_success) {
  let accountId = uid2console.get()?[uid.tostring()]
  logP($"invite {accountId}/{uid} to {currentSessionId}")
  if (currentSessionId && accountId)
    send(sessionManager.invite(currentSessionId, [accountId]),
         function(_r, e) { if (e == null) on_success() })
}

function join(session_id, _invitation_id, on_success) {
  currentContextId = createPushContext()
  currentSessionId = session_id
  logP($"join {currentSessionId} with {currentContextId}")
  let fetchSquadId = function(_r, _e) {
    
    send(sessionManager.list([session_id]), function(r, __e) {
          let encodedSquadId = r?.playerSessions?[0]?.customData1
          if (encodedSquadId)
            on_success(decodeString(encodedSquadId).tointeger())
        })
  }
  send(sessionManager.joinAsPlayer(session_id, createPlayerData(currentContextId)), fetchSquadId)
}

function leave() {
  logP($"leave {currentSessionId}")
  if (currentSessionId != null)
    send(sessionManager.leave(currentSessionId))
  currentSessionId = null
  currentContextId = null
}

return {
  create = createSession
  update_data = changeLeader
  invite = invite
  join = join
  leave = leave
}
