from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
import "matching.errors" as matching_errors
from "%ui/components/colors.nut" import Inactive, BtnBdHover, BtnBdHover

let { CmdHideAllUiMenus } = require("dasevents")
let { safeAreaHorPadding, safeAreaVerPadding } = require("%ui/options/safeArea.nut")
let {sub_txt, h2_txt} = require("%ui/fonts_style.nut")
let {showCreateRoom} = require("showCreateRoom.nut")
let { roomsList, roomsListError, roomsListRefreshEnabled, isRoomsListRequestInProgress} = require("roomsListState.nut")
let { joinRoom } = require("%ui/state/roomState.nut")
let { textButton } = require("%ui/components/button.nut")
let {textInput, textInputUnderlined} = require("%ui/components/textInput.nut")
let {showMsgbox} = require("%ui/components/msgbox.nut")
let {rand} = require("math")
let {makeVertScrollExt} = require("%ui/components/scrollbar.nut")
let {getCreateRoomWnd} = require("createRoom.nut")
let {tostring_any} = require("%sqstd/string.nut")
let {squadId} = require("%ui/squad/squadState.nut")
let {strip} = require("string")

function centeredText(text, options={}) {
  return {
    rendObj = ROBJ_TEXT
    text
    key = options?.key ?? text

    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
  }.__update(h2_txt)
}



let selectedRoom = Watched(null)

let scrollHandler = ScrollHandler()

function tryToJoin(roomInfo, cb, password="" ){
  let params = { roomId = roomInfo.roomId.tointeger() }
  if (squadId.get() != null)
    params.member <- { public = {squadId = squadId.get()} }
  if (roomInfo?.hasPassword)
    params.password <- strip(password)
  joinRoom(params, true, cb)
}

function mkFindSomeMatch(cb) {
  return function(){
    let candidates = []
    foreach (room in roomsList.get()) {
      if (room?.hasPassword)
        continue
      if (room.membersCnt >= (room?.maxPlayers ?? 0) || !room.membersCnt)
        continue
      candidates.append(room)
    }

    if (!candidates.len()) {
      showMsgbox({
        text = loc("Cannot find existing game. Create one?")
        buttons = [
          { text = loc("Yes"), action = @() showCreateRoom.set(true) }
          { text = loc("No")}
        ]
      })
    }
    else {
      let room = candidates[rand() % candidates.len()]
      tryToJoin(room, cb, "")
    }
  }
}

function fullRoomMsgBox(action) {
  showMsgbox({
    text = loc("msgboxtext/roomIsFull")
    buttons = [
      { text = loc("Yes"), action = action }
      { text = loc("No")}
    ]
  })
}

function joinCb(response) {
  if (response.error != matching_errors.OK){
    if (response.error == matching_errors.SERVER_ERROR_ROOM_FULL) {
      fullRoomMsgBox(mkFindSomeMatch(joinCb))
      return
    }

    showMsgbox({
      text = loc("msgbox/failedJoinRoom", "Failed to join room: {error}", {error=matching_errors.error_string(response.error)})
    })
  } else {
    selectedRoom.update(null)
  }
}
let findSomeMatch = mkFindSomeMatch(joinCb)

function doJoin() {
  let roomPassword = Watched("")
  let roomInfo = selectedRoom.get()
  if (roomInfo==null) {
    showMsgbox({text=loc("msgbox/noRoomTOJoin", "No room selected")})
    return
  }

  if (roomInfo && roomInfo?.hasPassword){
    function passwordInput() {
      local input = null

      if (roomInfo && roomInfo?.hasPassword) {
        input = textInput(roomPassword, {
          placeholder="password"
        })
      }

      return {
        key = "room-password"
        size = [sw(20), SIZE_TO_CONTENT]
        children = input
      }
    }

    showMsgbox({
      text = loc("This room requires password to join")
      children = passwordInput
      buttons = [
        { text = loc("Proceed"), action = function() {tryToJoin(roomInfo, joinCb, roomPassword.get())} }
        { text = loc("Cancel") }
      ]
    })
  }
  else
    tryToJoin(roomInfo, joinCb)
}


function itemText(text, options={}) {
  return {
    rendObj = ROBJ_TEXT
    text
    margin = fsh(1)
    size = ("pw" in options) ? [flex(options.pw), SIZE_TO_CONTENT] : SIZE_TO_CONTENT
  }.__update(sub_txt)
}


let colWidths = [25, 35, 12, 8, 25]

function listItem(roomInfo) {
  let stateFlags = Watched(0)

  local roomName = roomInfo?.roomName ?? tostring_any(roomInfo.roomId)
  if (roomInfo?.hasPassword)
    roomName = $"{roomName}*"

  return function() {
    local color
    if (selectedRoom.get() && (roomInfo.roomId == selectedRoom.get().roomId))
      color = BtnBdHover
    else
      color = (stateFlags.get() & S_HOVER) ? BtnBdHover : Color(0,0,0,0)

    return {
      rendObj = ROBJ_SOLID
      color = color
      size = [flex(), SIZE_TO_CONTENT]

      behavior = Behaviors.Button
      onClick = @() selectedRoom.set(roomInfo)
      onDoubleClick = doJoin
      onElemState = @(sf) stateFlags.set(sf)
      watch = [selectedRoom, stateFlags]
      key = roomInfo.roomId

      sound = {
        click  = "ui_sounds/button_click"
        hover  = "ui_sounds/button_highlight"
        active = "ui_sounds/button_action"
      }

      flow = FLOW_HORIZONTAL
      children = [
        itemText(roomName, {pw=colWidths[0]})
        itemText(loc(roomInfo?.sessionState ?? "no_session"), {pw=colWidths[2]})
        itemText(tostring_any(roomInfo?.membersCnt), {pw=colWidths[3]})
        itemText(roomInfo?.creator ?? loc("creator/auto"), {pw=colWidths[4]})
      ]
    }
  }
}


function listHeader() {
  return {
    hplace = ALIGN_CENTER
    size = [flex(), SIZE_TO_CONTENT]
    pos = [0, sh(11)]
    children = {
      size = [flex(), SIZE_TO_CONTENT]
      margin = [0, fsh(1), 0, 0]
      flow = FLOW_HORIZONTAL
      children = [
        itemText(loc("Name"), {pw=colWidths[0]})
        itemText(loc("Mod"), {pw=colWidths[1]})
        itemText(loc("Status"), {pw=colWidths[2]})
        itemText(loc("Players"), {pw=colWidths[3]})
        itemText(loc("Creator"), {pw=colWidths[4]})
      ]
    }
  }
}


let nameFilter = mkWatched(persist, "nameFilter", "")

function roomFilter() {
  return {
    size = [flex(), fsh(6)]

    vplace = ALIGN_BOTTOM
    halign = ALIGN_RIGHT

    flow = FLOW_HORIZONTAL
    onDetach = @() nameFilter.update("")
    onAttach = @() nameFilter.update("")
    children = [
      {
        size = [pw(colWidths[0] * 1.5), SIZE_TO_CONTENT]
        margin = [0, hdpx(10), 0, 0]
        children = textInputUnderlined(nameFilter,
          {
            placeholder=loc("search by name")
            onEscape = @() nameFilter("")
          }.__update(sub_txt))
      }
    ]
  }
}

function actionButtons() {
  local joinBtn
  if (selectedRoom.get()) {
    joinBtn = textButton(loc("Join"), doJoin, {hotkeys = [["^Enter"]]})
  }
  return {
    size = [SIZE_TO_CONTENT, fsh(6.5)] 
    watch = [selectedRoom]
    gap = hdpx(5)
    vplace = ALIGN_BOTTOM
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL

    children = [
      textButton(loc("Find custom game"), findSomeMatch, {hotkeys=[["^J:Y"]]})
      textButton(loc("Create game"), @() showCreateRoom.set(true), {hotkeys=[["^J:X | Enter"]]})
      joinBtn
    ]
  }
}



function getRoomsListScreen() {

  let filteredList = Computed(function() {
    let flt = nameFilter.get().tolower()
    if (flt.len() == 0)
      return clone roomsList.get()
    return roomsList.get().filter(function(room) {
      let roomName = room.public?.roomName || tostring_any(room.roomId)
      return (roomName.tolower().indexof(flt)!=null)
    })
  })

  function listContent() {
    return {
      size = [flex(), SIZE_TO_CONTENT]
      watch = filteredList
      flow = FLOW_VERTICAL
      children = filteredList.get().map(@(roomInfo) listItem(roomInfo))
    }
  }


  function roomsListComp() {
    return {
      size = [flex(), sh(60)]
      hplace = ALIGN_CENTER
      pos = [0, sh(15)]

      rendObj = ROBJ_FRAME
      color = Inactive
      borderWidth = [hdpx(2), 0]

      key = "rooms-list"

      valign = ALIGN_CENTER

      children = makeVertScrollExt(listContent, {
        scrollHandler
        rootBase = {
          size = flex()
          margin = [2, 0]
        }
      })
    }
  }


  let rooms = [
    listHeader
    @() {
      watch = roomsList
      children = roomsListComp
      size = flex()
    }
    {
      flow = FLOW_HORIZONTAL
      size = flex()
      children = [actionButtons, roomFilter]
    }
  ]

  let areThereRooms = Computed(@() roomsList.get().len()>0)

  function roomsListScreen() {
    let children = roomsListError.get()
      ? centeredText(loc("error/{0}".subst(roomsListError.get())))
      : !areThereRooms.get()
        ? [centeredText(loc("No custom games found")) actionButtons]
        : rooms

    return {
      children
      size = flex()
      onAttach = @() roomsListRefreshEnabled.set(true)
      onDetach = @() roomsListRefreshEnabled.set(false)

      watch = [
        roomsListError
        isRoomsListRequestInProgress
        areThereRooms
      ]
    }
  }

  return @() {
    size = flex()
    padding = [safeAreaVerPadding.get() + sh(5), safeAreaHorPadding.get() + sh(5)]
    onAttach = @() ecs.g_entity_mgr.broadcastEvent(CmdHideAllUiMenus())
    rendObj = ROBJ_WORLD_BLUR_PANEL
    stopMouse = true
    stopHotkeys = true
    color = Color(80,80,80,255)
    behavior = DngBhv.ActivateActionSet
    actionSet = "StopInput"

    halign = ALIGN_CENTER

    children = showCreateRoom.get() ?  getCreateRoomWnd() : roomsListScreen
    watch = [showCreateRoom, safeAreaHorPadding, safeAreaVerPadding]
  }
}

return {getRoomsListScreen}
