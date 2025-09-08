from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

#default:forbid-root-table

ecs.clear_vm_entity_systems()
require("%dngscripts/globalState.nut").setUniqueNestKey("Overlay")
let { isInBattleState } = require("%ui/state/appState.nut")
require("%ui/notifications/profileNotification.nut")
require("%ui/login/initLogin.nut")
require("%ui/profile/ribbonState.nut")
require("%ui/autotest_commands.nut")
let { eventbus_subscribe } = require("eventbus")

let { closeAllMenus } = require("%ui/hud/hud_menus_state.nut")
let { showCursor } = require("%ui/cursorState.nut")
let {serviceInfo} = require("%ui/service_info.nut")
let {dbgSafeArea} = require("%ui/dbgSafeArea.nut")
let {doesNavSceneExist, navScenesListGen, getTopNavScene} = require("%ui/navState.nut")

let {showUIinEditor, editorIsActive, editor} = require("editor.nut")
let {extraPropPanelCtors = null} = require("%daeditor/state.nut")
if (extraPropPanelCtors!=null)
  extraPropPanelCtors([require("editorCustomView.nut")])

require("%sqstd/regScriptDebugger.nut")(debugTableData)
require("%ui/backgroundContentUpdater.nut")

log($"loading overlay VM")

require("%ui/ui_config.nut")
require("voiceChat/voiceStateHandlers.nut")
require("%ui/state/roomState.nut")
require("%ui/notifications/webHandlers.nut")
let perfStats = require("%ui/hud/perf_stats.nut")
let {showDebriefing} = require("%ui/mainMenu/debriefing/debriefingState.nut")
let {debriefingUi} = require("%ui/mainMenu/debriefing/debriefingUi.nut")
let friendlyErrorsBtn = require("friendly_logerr.ui.nut")
let {hotkeysButtonsBar} = require("%ui/hotkeysPanel.nut")
let platform = require("%dngscripts/platform.nut")
let cursors = require("%ui/components/cursors.nut")
let {msgboxGeneration, getCurMsgbox } = require("%ui/components/msgbox.nut")
let {modalWindowsComponent, hideAllModalWindows} = require("%ui/components/modalWindows.nut")
let {isLoggedIn} = require("%ui/login/login_state.nut")
let globInput = require("%ui/glob_input.nut")
let {DBGLEVEL} = require("dagor.system")
set_nested_observable_debug( DBGLEVEL > 0)
require("daRg.debug").requireFontSizeSlot(DBGLEVEL>0 && VAR_TRACE_ENABLED) 
let {popupBlock} = require("%ui/popup/popupBlock.nut")
let { playerLogBlock, playerRewardBlock } = require("%ui/popup/player_event_log.nut")
let registerScriptProfiler = require("%sqstd/regScriptProfiler.nut")
let {safeAreaAmount, safeAreaVerPadding, safeAreaHorPadding} = require("%ui/options/safeArea.nut")
let {getCurrentLoginUi, loginUiVersion} = require("login/currentLoginUi.nut")
let {versionInfo, alphaWatermark} = require("versionInfo.nut")
let connectionInProgress = require("connectionInProgress.nut")
let {noServerStatus, saveDataStatus} = require("%ui/mainMenu/info_icons.nut")
let speakingList = require("%ui/speaking_list.nut")
let {onlineSettingUpdated} = require("%ui/options/onlineSettings.nut")
let { getCurrentLanguage } = require("dagor.localize")
let {language} = require("%ui/state/clientState.nut")
let replayHudLayout = require("%ui/hud/replay/replay_hud_layout.nut")
let { isReplay } = require("%ui/hud/state/replay_state.nut")
let {canShowReplayHud} = require("%ui/hud/replay/replayState.nut")
let hudComp = require("%ui/hud_root.nut")
let { queueTip } = require("%ui/queueWaitingInfo.nut")
let { hoverHotkeyHints } = require("%ui/components/pcHoverHotkeyHitns.nut")
let { subtitlesBlock } = require("%ui/hud/subtitles/subtitles.nut")
let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")
let { roundDebriefingUi } = require("%ui/hud/nexus_round_debriefing.nut")
let { selectLoadout } = require("%ui/hud/nexus_mode_loadout_selection_screen.nut")

require("%ui/sound_console.nut")
require("%ui/panels/panels.nut")
let { hasAlreadySetGamma, openGammaSettingWindow } = require("%ui/options/gamma_settings_window.nut")
hudIsInteractive.subscribe(@(v) !v ? hideAllModalWindows() : null)

isInBattleState.subscribe(function(_) {
  hideAllModalWindows()
  if (!hasAlreadySetGamma())
    openGammaSettingWindow()
})

if (platform.is_pc) {
  onlineSettingUpdated.subscribe(@(...) language(getCurrentLanguage()))
}


let {mkSettingsMenuUi, showSettingsMenu} = require("%ui/mainMenu/menus/settings_menu.nut")
let settingsMenuUi = mkSettingsMenuUi({onClose = @() showSettingsMenu(false)})

let {controlsMenuUi, showControlsMenu} = require("%ui/mainMenu/menus/controls_setup.nut")

let onPlatfomLoadModulePath = platform.is_sony ? "%ui/sony/onLoad.nut"
  : null
if (onPlatfomLoadModulePath != null)
  require(onPlatfomLoadModulePath)

require("send_player_loadout.nut")
require("send_player_permissions.nut")
require("netUtils.nut")
require("autoexec.nut")
require("%ui/charClient/charClient.nut")
require("sound_handlers.nut")
require("%ui/mainMenu/chat/chatState.nut").subscribeHandlers()
require("%ui/equipPresets/presetPatching.nut")
require("replay_finalize_session_es.nut")

function battleMenu(){
  local children = null
  if (showSettingsMenu.get())
    children = settingsMenuUi
  else if (showControlsMenu.get())
    children = controlsMenuUi
  if (showDebriefing.get())
    children = [debriefingUi, children]
  return {
    watch = [showControlsMenu, showSettingsMenu, showDebriefing]
    children
  }

}
registerScriptProfiler("overlay")

let msgboxesUI = @(){
  watch = msgboxGeneration
  children = getCurMsgbox()
}

let logerrsUi = @(){
  watch = safeAreaAmount
  halign = ALIGN_RIGHT
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER size = [sw(100)*safeAreaAmount.value, sh(100)*safeAreaAmount.value]
  children = friendlyErrorsBtn
}

let infoIcons = @(){
  margin = [max(safeAreaVerPadding.value/2.0,fsh(2)), max(safeAreaHorPadding.value/1.2,fsh(2))]
  watch = [safeAreaHorPadding, safeAreaVerPadding]
  children = [noServerStatus, saveDataStatus]
  hplace = ALIGN_RIGHT
  vplace = ALIGN_BOTTOM
  flow = FLOW_VERTICAL
}

let loginScreen = @(){
  watch = loginUiVersion
  children = getCurrentLoginUi()
  size = flex()
}

function curScreen(){
  local children = []
  if (isLoggedIn.get() == false) {
    children = [loginScreen]
    if (showSettingsMenu.get())
      children.append(settingsMenuUi)
  }
  else if (showSettingsMenu.get())
    children = [settingsMenuUi]
  else if (showControlsMenu.get())
    children = [controlsMenuUi]
  if (doesNavSceneExist(navScenesListGen.get()))
    children = children.append(getTopNavScene())
  return {
    size = flex()
    watch = [isLoggedIn, showDebriefing, showSettingsMenu, showControlsMenu, navScenesListGen]
    children
  }
}

let showUi = Computed(@() !editorIsActive.get() || showUIinEditor.get())


eventbus_subscribe("closeAllMenus", function(_){
  closeAllMenus()
})

let outOfBattleChildren = freeze([
  versionInfo, alphaWatermark,
  hudComp, curScreen,
  queueTip, connectionInProgress,
  modalWindowsComponent, msgboxesUI, popupBlock, playerLogBlock, speakingList, logerrsUi, infoIcons,
  subtitlesBlock, perfStats, hoverHotkeyHints, hotkeysButtonsBar, dbgSafeArea, globInput
])

let inBattleUiChildren = freeze([
  alphaWatermark, versionInfo, roundDebriefingUi, hudComp, selectLoadout,
  playerRewardBlock, battleMenu, modalWindowsComponent, msgboxesUI, playerLogBlock, speakingList, infoIcons,
  subtitlesBlock, perfStats, hoverHotkeyHints, hotkeysButtonsBar, dbgSafeArea, globInput
])

let replayHudChildren = freeze([
  hudComp, replayHudLayout, battleMenu,
  modalWindowsComponent, msgboxesUI,
  hotkeysButtonsBar, dbgSafeArea, globInput,
  {
    eventHandlers = {
      ["Replay.DisableHUD"] = @(_event) canShowReplayHud.modify(@(v) !v),
    }
  }
])

return function Root() {
  return {
    cursor = showCursor.get() ? cursors.normal : null
    key = showCursor.get()

    onAttach = function(){
      log($"Overlay UI started")
    }
    watch = [ isInBattleState, showUi, editorIsActive, showCursor ]
    children = []
      .extend(!showUi.get()
        ? []
        : isReplay.get()
          ? replayHudChildren
          : isInBattleState.get()
              ? inBattleUiChildren
              : outOfBattleChildren
      ).append(
        editorIsActive.get() ? editor : null,
        serviceInfo
      )
  }
}
