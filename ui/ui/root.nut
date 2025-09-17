from "%ui/ui_library.nut" import *
from "frame_label.nut" import frameLabel
import "%dngscripts/ecs.nut" as ecs
from "eventbus" import eventbus_subscribe
from "dagor.system" import DBGLEVEL
import "%dngscripts/platform.nut" as  platform
import "%sqstd/regScriptProfiler.nut" as registerScriptProfiler
from "dagor.localize" import getCurrentLanguage
from "frp" import warn_on_deprecated_methods
require("%ui/ui_config.nut")

#default:forbid-root-table

require("%dngscripts/globalState.nut").setUniqueNestKey("Overlay")
ecs.clear_vm_entity_systems()
let { isInBattleState } = require("%ui/state/appState.nut")
require("%ui/notifications/profileNotification.nut")
require("%ui/login/initLogin.nut")
require("%ui/profile/ribbonState.nut")
require("%ui/autotest_commands.nut")

let { closeAllMenus } = require("%ui/hud/hud_menus_state.nut")
let { showCursor } = require("%ui/cursorState.nut")
let {serviceInfo} = require("%ui/service_info.nut")
let {dbgSafeArea} = require("%ui/dbgSafeArea.nut")
let {doesNavSceneExist, navScenesListGen, getTopNavScene} = require("%ui/navState.nut")

let {showUIinEditor, editorIsActive, editor} = require("%ui/editor.nut")
let {extraPropPanelCtors = null} = require("%daeditor/state.nut")
if (extraPropPanelCtors!=null)
  extraPropPanelCtors.set([require("editorCustomView.nut")])

require("%sqstd/regScriptDebugger.nut")(debugTableData)
require("%ui/backgroundContentUpdater.nut")

log($"loading overlay VM")

require("%ui/voiceChat/voiceStateHandlers.nut")
require("%ui/state/roomState.nut")
require("%ui/notifications/webHandlers.nut")
let perfStats = require("%ui/hud/perf_stats.nut")
let {showDebriefing} = require("%ui/mainMenu/debriefing/debriefingState.nut")
let {debriefingUi} = require("%ui/mainMenu/debriefing/debriefingUi.nut")
let friendlyErrorsBtn = require("%ui/friendly_logerr.ui.nut")
let {hotkeysButtonsBar} = require("%ui/hotkeysPanel.nut")
let cursors = require("%ui/components/cursors.nut")
let {msgboxGeneration, getCurMsgbox } = require("%ui/components/msgbox.nut")
let {modalWindowsComponent, hideAllModalWindows} = require("%ui/components/modalWindows.nut")
let {isLoggedIn} = require("%ui/login/login_state.nut")
let globInput = require("%ui/glob_input.nut")
set_nested_observable_debug( DBGLEVEL > 0)
set_subscriber_validation( DBGLEVEL > 0)
warn_on_deprecated_methods( DBGLEVEL > 0 )
require("daRg.debug").requireFontSizeSlot(DBGLEVEL>0 && VAR_TRACE_ENABLED) 
let {popupBlock} = require("%ui/popup/popupBlock.nut")
let { playerLogBlock, playerRewardBlock } = require("%ui/popup/player_event_log.nut")
let {safeAreaAmount, safeAreaVerPadding, safeAreaHorPadding} = require("%ui/options/safeArea.nut")
let {getCurrentLoginUi, loginUiVersion} = require("%ui/login/currentLoginUi.nut")
let { versionInfo } = require("%ui/versionInfo.nut")
let connectionInProgress = require("%ui/connectionInProgress.nut")
let {noServerStatus, saveDataStatus} = require("%ui/mainMenu/info_icons.nut")
let speakingList = require("%ui/speaking_list.nut")
let { onlineSettingUpdated, changeSettingsWithPath } = require("%ui/options/onlineSettings.nut")
let { language, LANGUAGE_BLK_PATH } = require("%ui/state/clientState.nut")
let { replayHudLayout, isReplay } = require("%ui/hud/replay/replay_hud_layout.nut")
let hudComp = require("%ui/hud_root.nut")
let { queueTip } = require("%ui/queueWaitingInfo.nut")
let { hoverHotkeyHints } = require("%ui/components/pcHoverHotkeyHitns.nut")
let { subtitlesBlock } = require("%ui/hud/subtitles/subtitles.nut")
let { hudIsInteractive } = require("%ui/hud/state/interactive_state.nut")
let { roundDebriefingUi } = require("%ui/hud/nexus_round_debriefing.nut")
let { selectLoadout } = require("%ui/hud/nexus_mode_loadout_selection_screen.nut")

require("%ui/sound_console.nut")
require("%ui/panels/panels.nut")
let { hasAlreadySetGamma, openGammaSettingWindow, app_is_test_mode } = require("%ui/options/gamma_settings_window.nut")
hudIsInteractive.subscribe_with_nasty_disregard_of_frp_update(@(v) !v ? hideAllModalWindows() : null)

isInBattleState.subscribe_with_nasty_disregard_of_frp_update(function(_) {
  hideAllModalWindows()
  if (!hasAlreadySetGamma() && !app_is_test_mode())
    openGammaSettingWindow()
})

if (platform.is_pc) {
  onlineSettingUpdated.subscribe_with_nasty_disregard_of_frp_update(function(...) {
    changeSettingsWithPath(LANGUAGE_BLK_PATH, language.get())
  })
}


let {mkSettingsMenuUi, showSettingsMenu} = require("%ui/mainMenu/menus/settings_menu.nut")
let settingsMenuUi = mkSettingsMenuUi({onClose = @() showSettingsMenu.set(false)})

let {controlsMenuUi, showControlsMenu} = require("%ui/mainMenu/menus/controls_setup.nut")

let onPlatfomLoadModulePath = platform.is_sony ? "%ui/sony/onLoad.nut"
  : platform.is_gdk ? "%ui/gdk/onLoad.nut"
  : null
if (onPlatfomLoadModulePath != null)
  require(onPlatfomLoadModulePath)

require("%ui/send_player_loadout.nut")
require("%ui/send_player_permissions.nut")
require("%ui/netUtils.nut")
require("%ui/autoexec.nut")
require("%ui/charClient/charClient.nut")
require("%ui/sound_handlers.nut")
require("%ui/mainMenu/chat/chatState.nut").subscribeHandlers()
require("%ui/equipPresets/presetPatching.nut")
require("%ui/replay_finalize_session_es.nut")
require("%ui/playTimeTracker.nut")
require("%ui/checkPatchnotes.nut")

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
  vplace = ALIGN_CENTER size = [sw(100)*safeAreaAmount.get(), sh(100)*safeAreaAmount.get()]
  children = friendlyErrorsBtn
}

let infoIcons = @(){
  margin = [max(safeAreaVerPadding.get()/2.0,fsh(2)), max(safeAreaHorPadding.get()/1.2,fsh(2))]
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
    watch = [isLoggedIn, showSettingsMenu, showControlsMenu, navScenesListGen]
    children
  }
}

let showUi = Computed(@() !editorIsActive.get() || showUIinEditor.get())


eventbus_subscribe("closeAllMenus", function(_){
  closeAllMenus()
})

let outOfBattleChildren = freeze([
  versionInfo, hudComp, curScreen,
  queueTip, connectionInProgress,
  modalWindowsComponent, msgboxesUI, popupBlock, playerLogBlock, speakingList, logerrsUi, infoIcons,
  subtitlesBlock, perfStats, hoverHotkeyHints, hotkeysButtonsBar, dbgSafeArea, globInput
])

function inBattleCurScreen(){
  let children = []
  if (showSettingsMenu.get()){
    children.clear()
    children.replace([settingsMenuUi])
  }
  else if (showControlsMenu.get()) {
    children.clear()
    children.replace([controlsMenuUi])
  }
  if (doesNavSceneExist(navScenesListGen.get()))
    children.append(getTopNavScene())
  return {
    size = flex()
    watch = [showSettingsMenu, showControlsMenu, navScenesListGen]
    children
  }
}

let inBattleUiChildren = freeze([
  versionInfo, roundDebriefingUi, hudComp, selectLoadout,
  playerRewardBlock, battleMenu, inBattleCurScreen, modalWindowsComponent, msgboxesUI, playerLogBlock, speakingList, infoIcons,
  subtitlesBlock, hoverHotkeyHints, hotkeysButtonsBar, dbgSafeArea, globInput
])

let replayHudChildren = freeze([
  hudComp, replayHudLayout, battleMenu,
  modalWindowsComponent, msgboxesUI,
  hotkeysButtonsBar, dbgSafeArea, globInput,
])

gui_scene.forceCursorActive(showCursor.get())
showCursor.subscribe(@(v) gui_scene.forceCursorActive(v))

return function Root() {
  return {
    cursor = showCursor.get() ? cursors.normal : null
    key = showCursor.get()

    onAttach = function(){
      log($"Overlay UI started")
    }
    watch = [ isInBattleState, showUi, editorIsActive, showCursor, isReplay ]
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
        serviceInfo,
        frameLabel
      )
  }
}
