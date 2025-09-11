from "%ui/matchingClient.nut" import matchingCall

from "%ui/ui_library.nut" import *
import "math" as math
import "matching.errors" as matching_errors


let debugMode = mkWatched(persist, "debugMode", false)
let roomsList = mkWatched(persist, "roomsList", [])
let isRequestInProgress = mkWatched(persist, "isRequestInProgress", false)
let curError = Watched(null)

function listRoomsCb(response) {
  isRequestInProgress.set(false)
  if (debugMode.get())
    return
  if (response.error) {
    curError.set(matching_errors.error_string(response.error))
    roomsList.set([])
  } else {
    curError.set(null)
    roomsList.set(response.digest)
  }
}

function updateListRooms(){
  if (isRequestInProgress.get())
    return

  let params = {
    group = "custom-lobby"
    cursor = 0
    count = 100
    filter = {
    }
  }

  isRequestInProgress.set(true)
  matchingCall("mrooms.fetch_rooms_digest2", listRoomsCb, params)
}

let refreshPeriod = mkWatched(persist, "refreshPeriod", 5.0)
let refreshEnabled = mkWatched(persist, "refreshEnabled", false)

local wasRefreshEnabled = false
function toggleRefresh(val){
  if (!wasRefreshEnabled && val)
    updateListRooms()
  if(val)
    gui_scene.setInterval(refreshPeriod.get(), updateListRooms)
  else
    gui_scene.clearTimer(updateListRooms)
  wasRefreshEnabled = val
}
refreshEnabled.subscribe_with_nasty_disregard_of_frp_update(toggleRefresh)
toggleRefresh(refreshEnabled.get())
refreshPeriod.subscribe_with_nasty_disregard_of_frp_update(@(_v) toggleRefresh(refreshEnabled.get()))

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
    roomsList.set(list)
  }
  debugMode.set(!debugMode.get())
  if (debugMode.get()){
    refreshEnabled.set(false)
    debugRooms()
  }
  else{
    refreshEnabled.set(true)
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
