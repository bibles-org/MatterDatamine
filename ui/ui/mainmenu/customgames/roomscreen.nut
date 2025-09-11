from "%ui/state/roomState.nut" import connectToHost, startSession, leaveRoom, destroyRoom,
  startSessionWithLocalDedicated

from "%ui/fonts_style.nut" import body_txt, sub_txt
from "%ui/components/button.nut" import textButton
from "%ui/components/msgbox.nut" import showMsgbox
import "%ui/mainMenu/chat/chatRoom.nut" as chatRoom
from "%ui/helpers/remap_nick.nut" import remap_nick
from "dasevents" import CmdHideAllUiMenus

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
import "%ui/components/colors.nut" as colors
import "matching.errors" as matching_errors

let { safeAreaHorPadding, safeAreaVerPadding } = require("%ui/options/safeArea.nut")
let { lobbyStatus, roomMembers, room, chatId, canOperateRoom, LobbyStatus, canStartWithLocalDedicated } = require("%ui/state/roomState.nut")
let roomSettings = require("%ui/mainMenu/customGames/roomSettings.nut")
let { speakingPlayers } = require("%ui/voiceChat/voiceStateHandlers.nut")
let JB = require("%ui/control/gui_buttons.nut")

function startSessionCb(response) {
  function reportError(text) {
    console_print(text)
    showMsgbox({text=text})
  }

  if (response?.accept == false) 
    reportError("Failed to start session in room: {0}".subst(response?.reason ?? ""))
  else if (response.error != 0)
    reportError("Failed to start session in room: Battle servers not found")

}


function doStartSession() {
  startSession(startSessionCb)
}


function leaveRoomCb(response) {
  if (response.error) {
    showMsgbox({
      text = "Failed to leave room: {0}".subst(matching_errors.error_string(response.error))
    })
  }
}

function doLeaveRoom() {
  leaveRoom(leaveRoomCb)
}

function destroyRoomCb(response) {
  if (response.error) {
    showMsgbox({
      text = "Failed to destroy room: {0}".subst(matching_errors.error_string(response.error))
    })
  }
}

function doDestroyRoom() {
  destroyRoom(destroyRoomCb)
}

function memberInfoItem(member) {
  let colorSpeaking = Color(20, 220, 20, 255)
  let colorSilent = colors.TextHighlight
  return function() {
    let prefix = member.squadNum == 0 ? "" : $"[{member.squadNum}] "
    let text = prefix + remap_nick(member.name)

    return {
      watch = [speakingPlayers]
      color = speakingPlayers.get()?[member.name] ? colorSpeaking : colorSilent
      rendObj = ROBJ_TEXT
      text
      margin = fsh(1)
      hplace = ALIGN_LEFT
      validateStaticText = false
    }.__update(body_txt)
  }
}


function listContent() {
  let players = roomMembers.get()
    .filter(@(member) !member.public?.host)
  players.sort(@(a, b) (a.public?.squadId ?? 0) <=> (b.public?.squadId ?? 0))

  local squadNum = 0
  local prevSquadId = null
  foreach (player in players) {
    let squadId = player.public?.squadId
    if (squadId == null)
      player.squadNum <- 0
    else {
      if (squadId != prevSquadId) {
        squadNum += 1
        prevSquadId = squadId
      }
      player.squadNum <- squadNum
    }
  }

  let children = players.map(@(member) memberInfoItem(member))

  return {
    watch = [roomMembers]
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    size = FLEX_H
    children = children
  }
}


let header = {
  vplace = ALIGN_TOP
  rendObj = ROBJ_SOLID
  color = colors.WindowHeader
  size = static [flex(), fsh(4)]
  flow = FLOW_HORIZONTAL
  gap = hdpx(1)
  children = function() {
    local scene = null
    if (room.get()?.roomId) {
      scene = room.get().public?.title
      if (scene == null) {
        scene = room.get().public?.scene
        if (scene != null)
          scene = scene.split("/")
        if (scene && (scene?.len() ?? 0)>0)
          scene = scene[scene.len()-1]
      }
    }
    return {
      watch = room
      margin = static [fsh(1), fsh(3)]
      rendObj = ROBJ_TEXT
      text = room.get()?.roomId != null ?
        "{roomName}. {loccreator}{:} {creator}, {server}{:} {cluster}, {scene}".subst(room.get().public.__merge({
            scene, [":"]=":",loccreator=loc("Creator")
            server=loc("server")
            creator = remap_nick(room.get().public?.creator ?? "")
          })
        )
        :
        null
    }.__update(sub_txt)
  }
}


function membersListRoot() {
  return {
    size = static [flex(0.35), flex()]
    rendObj = ROBJ_FRAME
    color = colors.Inactive
    borderWidth = static [2, 0]
    padding = static [2, 0]

    key = "members-list"

    children = {
      size = flex()
      clipChildren = true

      children = {
        size = flex()
        flow = FLOW_VERTICAL

        behavior = Behaviors.WheelScroll

        children = listContent
      }
    }
  }
}


function statusText() {
  local text = ""
  let curLobbyStatus = lobbyStatus.get()
  if (curLobbyStatus == LobbyStatus.ReadyToStart)
    text = loc("lobbyStatus/ReadyToStart", {num_players = roomSettings.minPlayers.get(), start_game_btn=loc("lobby/startGameBtn")})
  else if (curLobbyStatus == LobbyStatus.NotEnoughPlayers)
    text = loc("lobbyStatus/NotEnoughPlayers")
  else if (curLobbyStatus == LobbyStatus.CreatingGame)
    text = loc("lobbyStatus/CreatingGame")
  else if (curLobbyStatus == LobbyStatus.GameInProgress)
    text = loc("lobbyStatus/GameInProgress")
  else if (curLobbyStatus == LobbyStatus.GameInProgressNoLaunched)
    text = loc("lobbyStatus/GameInProgressNoLaunched", {play=loc("lobby/playBtn")})
  else if (curLobbyStatus == LobbyStatus.WaitForDedicatedStart)
    text = loc("Wait for dedicated start")

  return {
    size = FLEX_H
    halign = ALIGN_CENTER
    watch = [
      lobbyStatus
    ]
    children = {
      rendObj = ROBJ_TEXT
      text = text
      color = Color(200,200,50)
    }.__update(body_txt)
  }
}


let startGameButton = textButton(loc("lobby/startGameBtn"), doStartSession,
  {
    hotkeys=[["^J:X"]]
    sound = {
      click  = "ui_sounds/start_game_click"
      hover  = "ui_sounds/button_highlight"
      active = "ui_sounds/button_action"
    }
  })

let actionButtons = @() {
  watch = [lobbyStatus, canOperateRoom]
  size = FLEX_H

  halign = ALIGN_CENTER
  flow = FLOW_HORIZONTAL
  children = [
    lobbyStatus.get() == LobbyStatus.ReadyToStart ? startGameButton : null,
    lobbyStatus.get() == LobbyStatus.GameInProgressNoLaunched
      ? textButton(loc("lobby/playBtn"), connectToHost)
      : null,
    canOperateRoom.get() && canStartWithLocalDedicated.get()
        && lobbyStatus.get() == LobbyStatus.ReadyToStart
      ? textButton("Start with local dedic", @() startSessionWithLocalDedicated(startSessionCb))
      : null,
    textButton(loc("lobby/leaveBtn"), doLeaveRoom, {hotkeys=[["^{0} | Esc".subst(JB.B)]]}),
    canOperateRoom.get()
      ? textButton(loc("lobby/destroyRoomBtn"), doDestroyRoom, {hotkeys=[["^J:Y"]]})
      : null
  ]
}

function chatRoot() {
  return {
    size = static [flex(0.65), flex()]
    children = chatRoom(chatId.get())
    watch = chatId
  }
}


function getRoomScreen() {
  return @() {
    size = flex()
    halign = ALIGN_CENTER
    rendObj = ROBJ_WORLD_BLUR_PANEL
    color = Color(80,80,80,255)
    padding = [safeAreaVerPadding.get() + sh(5), safeAreaHorPadding.get() + sh(5)]
    onAttach = @() ecs.g_entity_mgr.broadcastEvent(CmdHideAllUiMenus())
    stopMouse = true
    stopHotkeys = true
    behavior = DngBhv.ActivateActionSet
    actionSet = "StopInput"

    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      header
      statusText
      {
        size = static [flex(), flex(1)]
        flow = FLOW_HORIZONTAL
        gap = hdpx(10)
        children = [membersListRoot, chatRoot]
      }
      actionButtons
    ]
  }
}

return {getRoomScreen}
