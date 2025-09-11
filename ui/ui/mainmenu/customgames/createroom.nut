from "string" import startswith, strip
from "%ui/fonts_style.nut" import h2_txt, body_txt, sub_txt
from "%ui/permissions/permissions.nut" import checkMultiplayerPermissions
from "%ui/state/roomState.nut" import createRoom
from "%ui/components/button.nut" import textButton
from "%ui/components/textInput.nut" import textInput
import "%ui/components/checkbox.nut" as checkbox
from "%ui/components/msgbox.nut" import showMsgbox
import "%ui/components/combobox.nut" as comboBox
from "%ui/gameLauncher.nut" import startGame
from "app" import get_app_id
from "%ui/components/selectWindow.nut" import mkSelectWindow, mkOpenSelectWindowBtn
from "dasevents" import CmdHideAllUiMenus
from "%ui/profile/profileState.nut" import playerProfileLoadoutUpdate
import "%ui/profile/collectRaidProfile.nut" as collectRaidProfile
from "json" import object_to_json_string
from "%ui/helpers/parseSceneBlk.nut" import get_raid_description

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "%darg/laconic.nut" import *
import "matching.errors" as matching_errors

let { showCreateRoom } = require("%ui/mainMenu/customGames/showCreateRoom.nut")
let { oneOfSelectedClusters } = require("%ui/clusterState.nut")
let { groupSize, botsPopulation, botAutoSquad, scenes, scene, roomName, minPlayers, maxPlayers, startOffline, writeReplay } = require("%ui/mainMenu/customGames/roomSettings.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { alterMints, loadoutsAgency } = require("%ui/profile/profileState.nut")

let playersAmountList = [1, 2, 4, 8, 12, 16, 20, 24, 32, 40, 50, 64, 70, 80, 100, 128]
let groupSizes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]


let usePassword = mkWatched(persist, "usePassword", false)
let password = mkWatched(persist, "password", "")
let focusedField = Watched(null)

function createRoomCb(response) {
  if (response.error != 0) {
    roomName.set("")
    password.set("")

    showMsgbox({
      text = loc("customRoom/failCreate", {responce_error=matching_errors.error_string(response?.error_id ?? response.error)})
    })
  }
}

function availableFields() {
  return [
    roomName,
    usePassword,
    startOffline,
    (usePassword.get() ? password : null),
  ].filter(@(val) val)
}

function checkAvailableFields(){
  local isValid = true

  foreach (f in availableFields()) {
    if (type(f.get())=="string" && !strip(f.get()).len()) {
      anim_start(f)
      isValid = false
      break
    }
  }
  return isValid
}

function doCreateRoom() {
  if (!checkMultiplayerPermissions()) {
    log("no permissions to create lobby")
    return
  }
  let isValid = checkAvailableFields()

  if (isValid) {
    let offline = startOffline.get()
    local scenePath = scene.get()?.id
    let raidDescription = get_raid_description(scenePath)
    let raidType = raidDescription?.raidType ?? ""
    let nexus = startswith(raidType, "pvp")

    let params = {
      public = {
        maxPlayers = maxPlayers.get()
        roomName = strip(roomName.get())
        scene = scenePath
        cluster = oneOfSelectedClusters.get()
        appId = get_app_id()
        groupSize = groupSize.get()
        extraParams = {
          nexus
        }
      },
      lobby_template = "am_custom_games"
    }
    if (usePassword.get() && password.get())
      params.password <- strip(password.get())
    if (botsPopulation.get() > 0)
      params.public.botpop <- botsPopulation.get()

    if (botAutoSquad.get())
      params.public.botAutoSquad <- botAutoSquad.get()

    if (writeReplay.get())
      params.public.writeReplay <- true

    if (!offline){
      createRoom(params, createRoomCb)
    }
    else {
      ecs.g_entity_mgr.broadcastEvent(CmdHideAllUiMenus())
      local token = {
        loadoutItems = collectRaidProfile()
        mints = alterMints.get()
        loadouts_agency = loadoutsAgency.get()
      }
      playerProfileLoadoutUpdate(object_to_json_string(token))
      startGame({scene = scenePath})
    }
  }
}

function makeFormItemHandlers(field) {
  return {
    onFocus = @() focusedField.set(field)
    onBlur = @() focusedField.set(null)
    onAttach = function(elem) {
      let focusOn = focusedField.get()
      if (focusOn && field == focusOn)
        set_kb_focus(elem)
    }

    onReturn = doCreateRoom
  }
}

function formText(params) {
  let options = {
    placeholder = params?.placeholder ?? ""
  }.__update(params, makeFormItemHandlers(params.state))
  return textInput(params.state, options)
}


function formCheckbox(params={}) {
  return checkbox(params.state, params?.name, makeFormItemHandlers(params.state))
}

let titletxt = @(title){
  rendObj = ROBJ_TEXT
  text = title
  color = Color(180,180,180)
  vplace = ALIGN_CENTER
  size=[flex(), fontH(180)]
}.__update(sub_txt)

let formComboWithTitle = @(watch, values, title) {
  size=[flex(), fontH(180)]
  flow = FLOW_HORIZONTAL
  margin = hdpx(2)
  children = [
    titletxt(title)
    {
      size = [fontH(650), fontH(180)]
      hplace = ALIGN_RIGHT
      halign = ALIGN_RIGHT
      children = comboBox(watch, values, title)
    }
  ]
}.__update(body_txt)

let humanTitle = @(scn) (scn?.title ?? "_untitled_").replace(".blk", "")


let filterSceneStr = Watched("")

let closeRoomBtn = textButton(loc("mainmenu/btnClose"), function() {showCreateRoom.set(false)}, {hotkeys=[["^{0} | Esc".subst(JB.B)]]})
let createRoomBtn = textButton(loc("Create"), doCreateRoom, {hotkeys=[["^J:X"]]})

function getCreateRoomWnd() {

  let filteredScenes = Computed( function() {
    let fltr = (filterSceneStr.get() ?? "").tolower()
    if (fltr=="")
      return scenes.get()
    else
      return scenes.get().filter(@(v) (v?.title ?? "").tolower().contains(fltr) || (v?.id ?? "").tolower().contains(fltr))
  })

  let openScenesMenu = mkSelectWindow({
    uid = "scenes_selector",
    optionsState = filteredScenes,
    state = scene,
    title = loc("SELECT SCENE"),
    filterPlaceHolder=loc("filter scene")
    filterState = filterSceneStr
    mkTxt = humanTitle
    titleStyle = h2_txt
  })

  let selectSceneBtn = {
    size = static [flex(), sh(4)]
    children = mkOpenSelectWindowBtn(scene, openScenesMenu, humanTitle, loc("Current scene"))
  }
  return @() {
    size = static [fsh(40), sh(60)]
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    halign = ALIGN_CENTER
    valign = ALIGN_TOP
    key = "create-room"
    watch = usePassword
    children = [
      {
        flow = FLOW_VERTICAL
        size = FLEX_H
        children = [
          selectSceneBtn,
          formComboWithTitle(minPlayers, playersAmountList, loc("players to start")),
          formComboWithTitle(maxPlayers, playersAmountList, loc("Max players")),
          formComboWithTitle(botsPopulation, [0].extend(playersAmountList), loc("Bots population")),
          formCheckbox({state=botAutoSquad, name=loc("customRoom/botAutoSquad", "Fill the group with bots.")}),
          formComboWithTitle(groupSize, groupSizes, loc("Group size")),
          formText({state=roomName, placeholder = loc("customRoom/roomName_placeholder")}),
          formCheckbox({state=startOffline, name=loc("customRoom/startOffline")}),
          formCheckbox({state=usePassword, name=loc("customRoom/usePassword")}),
          (usePassword.get()
            ? formText({state=password placeholder=loc("password_placeholder","password") password="\u25CF"})
            : null),
          formCheckbox({state=writeReplay, name=loc("customRoom/writeReplay")})
        ]
      }
      function() {
        return {
          size = SIZE_TO_CONTENT
          watch = [startOffline]
          vplace = ALIGN_BOTTOM
          valign = ALIGN_CENTER
          flow = FLOW_HORIZONTAL
          children = [closeRoomBtn, createRoomBtn]
        }
      }
    ]
  }
}

return {getCreateRoomWnd}
