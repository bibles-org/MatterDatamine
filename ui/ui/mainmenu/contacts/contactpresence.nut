from "%ui/ui_library.nut" import *

let { nestWatched } = require("%dngscripts/globalState.nut")

const PRESENCES_ID = "presences"
const SQUAD_STATUS_ID = "squad_status"

let squadStatus = nestWatched(SQUAD_STATUS_ID, {})
let presences = nestWatched(PRESENCES_ID, {})

let calcStatus = @(presence) presence?.unknown ? null : presence?.online
let onlineStatusBase = Computed(@() presences.get().map(calcStatus))

let onlineStatus = Computed(@() onlineStatusBase.get().__merge(squadStatus.get()))

let updateSquadPresences = @(presense) squadStatus.mutate(function(old_status) {
  old_status.__update(presense.filter(@(v) v!=null))
})

function updatePresences(newPresences) {
  presences.mutate(@(old_presences) old_presences.__update(newPresences.filter(@(p) p != null)))
}

let isContactOnline = function(userId, onlineStatusVal) {
  let uid = type(userId) =="integer" ? userId.tostring() : userId
  return onlineStatusVal?[uid] == true
}

let mkContactOnlineStatus = @(userId) Computed(@() onlineStatus.get()?[userId])
let mkContactIsOnline = @(userId) Computed(@() isContactOnline(userId, onlineStatus.get()))

return {
  presences
  onlineStatus
  updatePresences
  updateSquadPresences

  isContactOnline
  mkContactOnlineStatus
  mkContactIsOnline
}