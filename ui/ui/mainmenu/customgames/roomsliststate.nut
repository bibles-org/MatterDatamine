from "%ui/ui_library.nut" import *
import "math" as math
import "matching.errors" as matching_errors

let { matchingCall } = require("%ui/matchingClient.nut")

let debugMode = mkWatched(persist, "debugMode", false)
let roomsList = mkWatched(persist, "roomsList", [])
let isRequestInProgress = mkWatched(persist, "isRequestInProgress", false)
let curError = Watched(null)

function listRoomsCb(response) {
  isRequestInProgress.update(false)
  if (debugMode.value)
    return
  if (response.error) {
    curError.update(matching_errors.error_string(response.error))
    roomsList.update([])
  } else {
    curError.update(null)
    roomsList.update(response.digest)
  }
}

function updateListRooms(){
  if (isRequestInProgress.value)
    return

  let params = {
    group = "custom-lobby"
    cursor = 0
    count = 100
    filter = {
    }
  }

  isRequestInProgress(true)
  matchingCall("mrooms.fetch_rooms_digest2", listRoomsCb, params)
}

let refreshPeriod = mkWatched(persist, "refreshPeriod", 5.0)
let refreshEnabled = mkWatched(persist, "refreshEnabled", false)

local wasRefreshEnabled = false
function toggleRefresh(val){
  if (!wasRefreshEnabled && val)
    updateListRooms()
  if(val)
    gui_scene.setInterval(refreshPeriod.value, updateListRooms)
  else
    gui_scene.clearTimer(updateListRooms)
  wasRefreshEnabled = val
}
refreshEnabled.subscribe(toggleRefresh)
toggleRefresh(refreshEnabled.value)
refreshPeriod.subscribe(@(_v) toggleRefresh(refreshEnabled.value))

function switchDebugMode() {
  function debugRooms() {
    let list = array(100).map(@(_) {
        roomId = math.rand()
        membersCnt = 2 + math.rand() % 25
        public = {
          creator = "%Username%{0}".subst(math.rand()%11)
          hasPassword = !(math.rand()%3)
        }
      }
    )
    roomsList.update(list)
  }
  debugMode.update(!debugMode.value)
  if (debugMode.value){
    refreshEnabled.update(false)
    debugRooms()
  }
  else{
    refreshEnabled.update(true)
  }
}

console_register_command(switchDebugMode, "rooms.switchDebugMode")

return {
  roomsList
  roomsListError = curError
  isRoomsListRequestInProgress = isRequestInProgress
  roomsListRefreshPeriod = refreshPeriod
  roomsListRefreshEnabled = refreshEnabled
  _manualRefresh = updateListRooms
}
