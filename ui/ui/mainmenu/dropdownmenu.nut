from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

from "%ui/components/msgbox.nut" import showMsgbox

let { isInQueue } = require("%ui/quickMatchQueue.nut")
let { isInSquad } = require("%ui/squad/squadManager.nut")
let { customGamesOpen } = require("%ui/mainMenu/customGames/customGamesWnd.nut")
let {openSquadChat, squadChatExists} = require("%ui/squad/squadChat.nut")
let { showControlsMenu } = require("%ui/mainMenu/menus/controls_setup.nut")
let { showSettingsMenu } = require("%ui/mainMenu/menus/settings_menu.nut")
let { exitGameMsgBox } = require("%ui/mainMsgBoxes.nut")
let { openDevInfo } = require("%ui/devInfo.nut")
let { squareIconButton, textButton } = require("%ui/components/button.nut")
let { addModalPopup, removeModalPopup } = require("%ui/components/modalPopupWnd.nut")
let {isGamepad} = require("%ui/control/active_controls.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { showCursor } = require("%ui/cursorState.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let { isOnboarding, isOnboardingMemory } = require("%ui/hud/state/onboarding_state.nut")
let { CmdOpenDebriefingRequest, CmdInterruptOnboardingMemory } = require("dasevents")
let {switch_to_menu_scene} = require("%sqGlob/app_control.nut")
let { endgameControllerState } = require("%ui/hud/state/endgame_controller_state.nut")
let { EndgameControllerState } = require("%sqGlob/dasenums.nut")
let { localPlayerEid } = require("%ui/hud/state/local_player.nut")
let { isAlive } = require("%ui/hud/state/health_state.nut")
let qrWindow = require("qrWindow.nut")
let { get_setting_by_blk_path } = require("settings")
let { DBGLEVEL } = require("dagor.system")
let platform = require("%dngscripts/platform.nut")
let openUrl = require("%ui/components/openUrl.nut")

let SEPARATOR = freeze({})
let CBR_URL = get_setting_by_blk_path("cbrUrl") ?? "https://community.gaijin.net/issues/p/active_matter?from-ts=1714510800&to-ts=1733000399"

let btnOptions = {
  name = loc("gamemenu/btnOptions")
  id = "Options"
  cb = function() {
    showSettingsMenu(true)
  }
  icon = "menu_icon_options"
}
let btnControls = {
  id = "Controls"
  name = loc("gamemenu/btnBindKeys")
  cb = function() {
    showControlsMenu(true)
  }
}
let btnExit = {
  id = "Exit"
  name = loc("Exit Game")
  cb = exitGameMsgBox
}
let btnExitOnboardingMemory = {
  id = "ExitOnboardingMemory"
  name = loc("gamemenu/btnExitBattle")
  cb = @() ecs.g_entity_mgr.broadcastEvent(CmdInterruptOnboardingMemory())
}
let btnExitBattle = {
  id = "ExitBattle"
  name = loc("gamemenu/btnExitBattle")
  cb = function() {
    showMsgbox({
      text = loc("exit_game_confirmation")
      buttons = [
        { text=loc("Yes"), action = switch_to_menu_scene }
        { text=loc("No"), isCurrent = true}
      ]
    })
  }
}
let btnCustomGames = {
  id  = "CustomGames"
  name = loc("Custom games")
  cb = customGamesOpen
}
let btnSquadChat = {
  id = "SquadChat"
  name = loc("Squad Chat")
  cb = openSquadChat
}
let btnDevInfo = {
  id = "DevInfo"
  name = "Dev Info"
  cb = openDevInfo
}
let btnCBR = CBR_URL == "" ? null : {
  id = "Cbr"
  name = loc("button/cbr")
  cb = @() platform.is_pc ? openUrl(CBR_URL) : qrWindow({url = CBR_URL, header = loc("button/cbr")})
}
let btnDebriefing = {
  id = "Debriefing"
  name = loc("gamemenu/btnDebriefing")
  cb = @() ecs.g_entity_mgr.sendEvent(localPlayerEid.get(), CmdOpenDebriefingRequest())
}

let commonButtons = [btnOptions, btnControls, btnCBR]

function getButtons(buttons) {
  let res = []
    .extend(buttons)
    .append(buttons.len() > 0 ? SEPARATOR : null)
  if (isInBattleState.get() && endgameControllerState.get() == EndgameControllerState.SPECTATING)
    res.append(btnDebriefing)
  if (!isInBattleState.get() && DBGLEVEL > 0)
    res.append(btnDevInfo)
  if (squadChatExists.get() && isInSquad.get()) {
    res.insert(0, SEPARATOR)
    res.insert(0, btnSquadChat)
  }
  if (!isInBattleState.get() && !isInQueue.get() && DBGLEVEL > 0) {
    res.insert(0, SEPARATOR)
    res.insert(0, btnCustomGames)
  }
  res.extend(commonButtons)

  
  if (isOnboardingMemory.get())
    res.append(btnExitOnboardingMemory)
  else if (isInBattleState.get() && !isOnboarding.get())
    res.append(btnExitBattle)
  else
    res.append(btnExit)
  return res
}

let popupBg = {}

const WND_UID = "main_menu_header_buttons"
let close = @() removeModalPopup(WND_UID)

function closeWithCb(cb) {
  cb()
  removeModalPopup(WND_UID)
}

let mkButton = @(btn, needMoveCursor) (btn?.len() ?? 0) > 0
  ? textButton(btn.name, @() closeWithCb(btn.cb), {
      size = [flex(), SIZE_TO_CONTENT]
      minWidth = SIZE_TO_CONTENT
      margin = 0
      borderWidth = 0
      borderRadius = 0
      textMargin = [hdpx(8), hdpx(15)]
      sound = {
        click = "ui_sounds/menu_enter"
        hover = "ui_sounds/menu_highlight"
      }
    }.__update(needMoveCursor ? {
        behavior = Behaviors.Button
        key = "selected_menu_elem"
        function onAttach() {
          move_mouse_cursor("selected_menu_elem", false)
        }
      } : {}))
  : {
      rendObj = ROBJ_SOLID
      size = [flex(), hdpx(1)]
      color = Color(50,50,50)
    }


function mkMenuButtonsUi(buttons){
  let children = getButtons(buttons).map(@(btn, idx) mkButton(btn, isGamepad.get() && idx == 0))
  return @() {
    rendObj = ROBJ_BOX
    fillColor = Color(0,0,0)
    borderRadius = hdpx(4)
    borderWidth = 0
    flow = FLOW_VERTICAL
    children
    watch = [isInQueue, squadChatExists, isInSquad, endgameControllerState, isInBattleState, isOnboarding, isAlive]
  }
}


function fabtn(icon, onClick){
  let group = ElemGroup()
  let btn = squareIconButton({
    iconId = icon
    size = [hdpx(45)*0.75, hdpx(45)]
    onClick
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    skipDirPadNav=true
    group
    isEnable = showCursor
  })
  return {
    group
    onClick
    skipDirPadNav=true
    children = btn
    padding = [0, fsh(1)]
  }
}

let mkDropDownMenu = @(buttons = null) function(event) {
  let {targetRect} = event
  addModalPopup([targetRect.r, targetRect.b], {
    uid = WND_UID
    padding = 0
    children = mkMenuButtonsUi(buttons ?? [])
    popupOffset = hdpx(5)
    popupHalign = ALIGN_RIGHT
    popupBg
    hotkeys = [[$"^J:Start | {JB.B} | Esc", { action = close, description = loc("Cancel") }]]
  })
}

return {
  SEPARATOR
  mkDropDownMenuBtn = function(buttons = null) {
    let onClick = mkDropDownMenu(buttons)
    return fabtn("list-ul", onClick)
  }
  mkDropDownMenu
}
