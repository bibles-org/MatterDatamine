from "%sqGlob/app_control.nut" import switch_to_menu_scene
from "%sqGlob/dasenums.nut" import EndgameControllerState
from "%ui/changeLogState.nut" import changelogDisabled
from "%ui/mainMenu/customGames/customGamesWnd.nut" import customGamesOpen
from "%ui/mainMsgBoxes.nut" import exitGameMsgBox
from "%ui/devInfo.nut" import openDevInfo
from "%ui/components/button.nut" import squareIconButton, textButton
from "%ui/components/modalPopupWnd.nut" import addModalPopup, removeModalPopup
from "dasevents" import CmdOpenDebriefingRequest, CmdInterruptOnboardingMemory
import "%ui/mainMenu/qrWindow.nut" as qrWindow
from "settings" import get_setting_by_blk_path
from "%ui/hud/tips/tipComponent.nut" import tipCmp
from "dagor.system" import DBGLEVEL
from "%ui/components/openUrl.nut" import openUrl
from "%sqGlob/appInfo.nut" import version, circuit
from "%ui/profile/profileState.nut" import playerStats
from "eventbus" import eventbus_send
from "%ui/openChangelog.nut" import openChangelog
from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
from "%ui/components/msgbox.nut" import showMsgbox

let { isInQueue } = require("%ui/quickMatchQueue.nut")
let { isInSquad } = require("%ui/squad/squadManager.nut")
let { showControlsMenu } = require("%ui/mainMenu/menus/controls_setup.nut")
let { showSettingsMenu } = require("%ui/mainMenu/menus/settings_menu.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let JB = require("%ui/control/gui_buttons.nut")
let { showCursor } = require("%ui/cursorState.nut")
let { isInBattleState } = require("%ui/state/appState.nut")
let { isOnboarding, isOnboardingMemory } = require("%ui/hud/state/onboarding_state.nut")
let { endgameControllerState } = require("%ui/hud/state/endgame_controller_state.nut")
let { localPlayerEid } = require("%ui/hud/state/local_player.nut")
let { isAlive } = require("%ui/hud/state/health_state.nut")
let platform = require("%dngscripts/platform.nut")
let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")
let { savePlayerPresetsToLocal, loadPlayerPresetsFromLocal } = require("%ui/equipPresets/presetPatching.nut")

let SEPARATOR = freeze({})
let CBR_URL = get_setting_by_blk_path("cbrUrl") ?? "https://community.gaijin.net/issues/p/active_matter/new_issue"

let btnOptions = {
  name = loc("gamemenu/btnOptions")
  id = "Options"
  cb = function() {
    showSettingsMenu.set(true)
  }
  icon = "menu_icon_options"
}
let btnControls = {
  id = "Controls"
  name = loc("gamemenu/btnBindKeys")
  cb = function() {
    showControlsMenu.set(true)
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
let btnDevInfo = {
  id = "DevInfo"
  name = "Dev Info"
  cb = openDevInfo
}
let btnCBR = CBR_URL == "" ? null : {
  id = "Cbr"
  name = loc("button/cbr")
  cb = function(){
    let finalUrl = "{url}?f.platform={platform}&f.version={version}&f.circuit={circuit}".subst({
      url = CBR_URL
      platform = platform.platformId
      version = version.get()
      circuit = circuit.get()
    })
    if (platform.is_pc) {
      openUrl(finalUrl)
    }
    else
      qrWindow({url = finalUrl, header = loc("button/cbr")})
  }
}
let btnDebriefing = {
  id = "Debriefing"
  name = loc("gamemenu/btnDebriefing")
  cb = @() ecs.g_entity_mgr.sendEvent(localPlayerEid.get(), CmdOpenDebriefingRequest())
}

let btnProfileReset = {
  id = "ProfileReset"
  name = "Reset Profile"
  cb = @() eventbus_send("profile.reset")
}

let btnSavePresets = {
  id = "SavePresetsToLocal"
  name = "Save presets to file"
  cb = savePlayerPresetsToLocal
}

let btnLoadPresets = {
  id = "LoadPresetsFromLocal"
  name = "Load presets from file"
  cb = loadPlayerPresetsFromLocal
}

let btnChangelog = changelogDisabled ? null : {
  id = "Changelog"
  name = loc("gamemenu/btnChangelog")
  cb = openChangelog
}

let commonButtons = [btnOptions, btnControls, btnCBR]

function getButtons(buttons) {
  let res = []
    .extend(buttons)
    .append(isInBattleState.get() ? null : btnChangelog)
    .append(buttons.len() > 0 ? SEPARATOR : null)
  if (isInBattleState.get() && endgameControllerState.get() == EndgameControllerState.SPECTATING)
    res.append(btnDebriefing)
  if (!isInBattleState.get() && DBGLEVEL > 0)
    res.append(btnDevInfo)
  if (!isInBattleState.get() && !isInQueue.get() && DBGLEVEL > 0) {
    res.insert(0, SEPARATOR)
    res.insert(0, btnCustomGames)
  }
  if (!isInBattleState.get() && !isOnboardingMemory.get()
        && !isOnboarding.get() && playerStats.get().unlocks.contains("unlock_promo_account")) {
    res.append(btnProfileReset, btnSavePresets, btnLoadPresets)
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
      size = FLEX_H
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
      size = static [flex(), hdpx(1)]
      color = Color(50,50,50)
    }


function mkMenuButtonsUi(buttons){
  let children = getButtons(buttons)
    .filter(@(btn) btn != null)
    .map(@(btn, idx) mkButton(btn, isGamepad.get() && idx == 0))
  return @() {
    rendObj = ROBJ_BOX
    fillColor = Color(0,0,0)
    borderRadius = hdpx(4)
    borderWidth = 0
    flow = FLOW_VERTICAL
    children
    watch = [isInQueue, isInSquad, endgameControllerState, isInBattleState, isOnboarding, isAlive, playerStats]
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
    padding = static [0, fsh(1)]
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

let activateBtnRect = { r = hdpx(20), b = hdpx(20) }
function onAttachActivateBtn(elem) {
  let x = elem.getScreenPosX()
  let height = elem.getContentHeight()
  let width = elem.getWidth()
  activateBtnRect.__update({ r = x + width, b = height })
}

let gamepadDropDownMenuBtn = @(onClick) @() {
  watch = hudIsInteractive
  eventHandlers = {
    ["HUD.SystemMenu"] = @(_) onClick({targetRect = activateBtnRect})
  }
  onAttach = onAttachActivateBtn
  behavior = hudIsInteractive.get() ? Behaviors.Button : null
  onClick = @() onClick({targetRect = activateBtnRect})
  skipDirPadNav = true
  children = tipCmp({
    inputId = "HUD.SystemMenu"
    animations = []
    style = {
      rendObj = ROBJ_BOX
      padding = static [hdpx(8), hdpx(5), hdpx(15), hdpx(5)]
      fillColor = Color(0,0,0,0)
    }
  })
}

return {
  SEPARATOR
  mkDropDownMenuBtn = function(buttons = null) {
    let onClick = mkDropDownMenu(buttons)
    return @() {
      watch = isGamepad
      children = isGamepad.get() ? gamepadDropDownMenuBtn(onClick) : fabtn("list-ul", onClick)
    }
  }
  mkDropDownMenu
}
