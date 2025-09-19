from "eventbus" import eventbus_send
from "videomode" import apply_video_settings
from "%ui/mainMenu/menus/options/options_lib.nut" import isOption
from "%ui/components/button.nut" import textButton
import "%ui/mainMenu/menus/settingsMenu.nut" as settingsMenuCtor
from "%ui/components/msgbox.nut" import showMsgbox
from "settings" import save_changed_settings, get_setting_by_blk_path, set_setting_by_blk_path, save_settings, remove_setting_by_blk_path
from "app" import reload_ui_scripts, reload_overlay_ui_scripts
from "%ui/mainMenu/menus/options/camera_fov_option.nut" import cameraFovOption
from "%ui/mainMenu/menus/options/flashlight_tip_option.nut" import flashlightTipOption
from "%ui/mainMenu/menus/options/player_interaction_option.nut" import friendsInvitationOption, streamerModeOption
from "%ui/mainMenu/menus/options/quality_preset_option.nut" import optGraphicsQualityPreset
from "%ui/mainMenu/menus/options/miss_second_map_help.nut" import missSecondMapHelp, missSecondMiscNotifications, missSecondSarcasm
from "%ui/mainMenu/menus/options/chocolate_matrix_option.nut" import chocolateRowOption, chocolateColOption
from "%ui/ui_library.nut" import *
from "modules" import on_module_unload
from "%dngscripts/globalState.nut" import nestWatched

let { showSettingsMenu } = require("%ui/mainMenu/menus/menuState.nut")
let logMenu = require("%sqGlob/library_logs.nut").with_prefix("[SettingsMenu] ")
let {apply_audio_settings=@(_fieilds) null} = require_optional("dngsound")
let JB = require("%ui/control/gui_buttons.nut")
let { renderOptions, optLanguage } = require("%ui/mainMenu/menus/options/render_options.nut")
let { soundOptions } = require("%ui/mainMenu/menus/options/sound_options.nut")
let { voiceChatOptions } = require("%ui/mainMenu/menus/options/voicechat_options.nut")
let { onlineSettingUpdated } = require("%ui/options/onlineSettings.nut")

let settingsForRestart = mkWatched(persist, "settingsForRestart", {})

let menuTabsOrder = freeze([
  {id = "Graphics", text=loc("options/graphicsParameters")},
  {id = "Sound", text = loc("sound")},
  {id = "Game", text = loc("options/game")},
  {id = "VoiceChat", text = loc("controls/tab/VoiceChat")},
  {id = "Streaming", text = loc("options/streaming")}
])

let getMenuOptions = @() [optLanguage, flashlightTipOption, cameraFovOption, optGraphicsQualityPreset, missSecondMapHelp,
  missSecondMiscNotifications, missSecondSarcasm, chocolateRowOption, chocolateColOption, friendsInvitationOption, streamerModeOption
].extend(renderOptions, soundOptions, voiceChatOptions)

let closeMenu = @() showSettingsMenu.set(false)


let foundTabsByOptionsGen = Watched(0)
let foundTabsByOptionsContainer = []
let getFoundTabsByOptions = @(...) foundTabsByOptionsContainer
function setFoundTabsByOptions(v){
  foundTabsByOptionsContainer.replace(v)
  foundTabsByOptionsGen.modify(@(i) i+1)
}

let resultOptionsGen = Watched(0)
let resultOptionsContainer = []
let getResultOptions = @(...) resultOptionsContainer
function resultOptions(v){
  resultOptionsContainer.replace(v)
  resultOptionsGen.modify(@(i) i+1)
}

function setResultOptions(...){
  local optionsValue = getMenuOptions()
  let tabsInOptions = {}
  let isAvailableTriggers = optionsValue
    .filter(@(opt) opt?.isAvailableWatched!=null)
    .map(@(opt) opt.isAvailableWatched)

  optionsValue = optionsValue.filter(@(opt) isOption(opt) && (
    (opt?.isAvailable == null && opt?.isAvailableWatched == null)
    || (opt?.isAvailableWatched.get() ?? opt?.isAvailable() ?? false)
  ))
  let res = []
  local lastSeparator = null
  let optionsStack = []

  foreach (opt in optionsValue) {
    if (opt?.tab != null ) {
      if (tabsInOptions?[opt.tab] == null)
        tabsInOptions[opt.tab] <- true
    }
    else {
      tabsInOptions["__unknown__"] <- true
    }

    if (opt?.isSeparator) {
      if (lastSeparator != null) {
        optionsStack.insert(0, lastSeparator)
        lastSeparator = null
      }
      res.extend(optionsStack)

      optionsStack.clear()
      lastSeparator = opt
    }
    else {
      optionsStack.append(opt)

      if (opt == optionsValue.top()) { 
        if (lastSeparator != null)
          res.append(lastSeparator)
        res.extend(optionsStack)
      }
    }
  }
  resultOptions(res)
  setFoundTabsByOptions(tabsInOptions.keys())
  foreach(i in isAvailableTriggers)
    i.subscribe_with_nasty_disregard_of_frp_update(setResultOptions)
}
setResultOptions()

function getResultTabs(foundTabsByOptionsValue, tabsOrder){
  let selectedTabs = []
  let ret = []
  foreach (tab in tabsOrder) {
    if (foundTabsByOptionsValue.indexof(tab?.id)!=null && selectedTabs.indexof(tab?.id)==null) {
      ret.append(tab)
      selectedTabs.append(tab.id)
    }
  }
  foreach (id in foundTabsByOptionsValue)
    if (tabsOrder.findindex(@(tab) tab?.id == id) == null)
      ret.append({id=id, text=loc(id)})
  return ret
}

let curTab = nestWatched("curTab")
let currentTab = nestWatched("currentTab", menuTabsOrder?[0].id)

function checkAndApply(available, val, defVal, blkPath) {
  if (available == null)
    return val

  if (available instanceof Watched)
    available = available.get()
  if (typeof available != "array")
    available = [available]
  if (available.contains(val))
    return val

  logMenu($"{blkPath} absent value:", val, "default:", defVal, "available:", available)
  if (defVal != null)
    return defVal
  if (available.len() > 0)
    return available[0]

  logMenu($"{blkPath} absent value:", val, "no default values")
  return val
}


function backupRestartRequiredSettings() {
  
  remove_setting_by_blk_path("onReloadChanges")

  if (settingsForRestart.get().len() != 0) {
    
    foreach (blkPath, val in settingsForRestart.get())
      set_setting_by_blk_path($"onReloadChanges/{blkPath}", val)

    settingsForRestart.set({})
  }
  save_settings()
}


let convertForBlkByType = {
  float = @(v) v.tofloat()
  integer = @(v) v.tointeger()
  string = @(v) v.tostring()
  bool = @(v) !!v
}
function applyGameSettingsChanges(optionsValue, silentApply = false) {
  let onCloseActions = {
    needNotifyRestart = false
    needReload = false
  }

  let changedFields = []
  foreach (opt in optionsValue) {
    let { blkPath = null } = opt
    if (blkPath) {
      let { defVal = null } = opt
      let isEq = opt.isEqual
      local hasChanges = false
      local val = opt.var.get()
      if ("convertForBlk" in opt)
        val = opt.convertForBlk(val)
      else if ("typ" in opt && opt.typ in convertForBlkByType) {
        try {
          let cval = convertForBlkByType[opt.typ](val)
          let { available = null } = opt
          let res = checkAndApply(available, cval, defVal, blkPath)
          if (!isEq(res, cval)) {
            val = res
            changedFields.append(blkPath)
          } else
            val = cval
        }
        catch(e) {
          logMenu("error in loading ", opt, e)
          val = defVal
          changedFields.append(blkPath)
        }
      }

      if (opt?.restart) {
        let optSavedValue = get_setting_by_blk_path(blkPath) ?? defVal
        if (!isEq(optSavedValue, val) && val != null) {
          settingsForRestart.mutate(function(v) {
            
            v[blkPath] <- val

            
            foreach (moreSetting in opt?.getMoreBlkSettings(val) ?? [])
              v[moreSetting.blkPath] <- moreSetting.val
          })
          logMenu($"{blkPath}, {val} marked as 'restart required'. Saved until restart game")
        }
        else if (blkPath in settingsForRestart.get()) {
          settingsForRestart.mutate(function(v) {
            
            v.$rawdelete(blkPath)

            
            foreach (moreSetting in opt?.getMoreBlkSettings(val) ?? [])
              v.$rawdelete(moreSetting.blkPath)
          })

          logMenu($"{blkPath} marked as 'restart required'. Restored last saved value. Remove from save queue.")
        }
        continue
      }

      let blksettings = [{ blkPath, val, defVal }]
      if ("getMoreBlkSettings" in opt)
        blksettings.extend(opt.getMoreBlkSettings(val))

      foreach (setting in blksettings) {
        logMenu(setting.blkPath, get_setting_by_blk_path(setting.blkPath), setting?.defVal, setting.val)
        let savedValue = get_setting_by_blk_path(setting.blkPath) ?? setting?.defVal
        if (!isEq(savedValue, setting.val) && setting.val != null) {
          
          if (type(get_setting_by_blk_path(setting.blkPath)) != type(setting.val))
            remove_setting_by_blk_path(setting.blkPath)
          set_setting_by_blk_path(setting.blkPath, setting.val)
          changedFields.append(setting.blkPath)
          hasChanges = true
        }
      }

      if (hasChanges && opt?.reload)
        onCloseActions.needReload = true
    }
  }

  if (!silentApply && settingsForRestart.get().len())
    onCloseActions.needNotifyRestart = true

  backupRestartRequiredSettings()

  if (changedFields.len() != 0) {
    logMenu("apply changes", changedFields)
    save_changed_settings(changedFields)
    apply_video_settings(changedFields)
    apply_audio_settings(changedFields)
  }
  return onCloseActions
}

function doReload() {
  defer(function() {
    reload_overlay_ui_scripts()
    reload_ui_scripts()
  })
}

let saveAndApply = @(onMenuClose, options) function() {
  let onCloseActions = applyGameSettingsChanges(options)
  onMenuClose()
  eventbus_send("onlineSettings.sendToServer", null)

  if (onCloseActions.needNotifyRestart) {
    showMsgbox({
      text = loc("settings/restart_needed")
      buttons = [{ text = loc("Ok"), isCurrent = true
          action = onCloseActions.needReload ? doReload : null }]
    })
  }
  else if (onCloseActions.needReload)
    doReload()
}

if (onlineSettingUpdated) {
  onlineSettingUpdated.subscribe(
    @(val) val ? defer(@() applyGameSettingsChanges(resultOptionsContainer)) : null
  )
  applyGameSettingsChanges(getResultOptions())
}

function mkSettingsMenuUi(menu_params) {
  function close(){
    menu_params?.onClose()
    closeMenu()
  }
  return function(){
    let optionsValue = getResultOptions()
    let tabs = getResultTabs(getFoundTabsByOptions(), menuTabsOrder)
    return {
      size = flex()
      key = "settings_menu_root"
      onDetach = @() curTab.set(tabs?[0].id ?? "")
      function onAttach(){
        if ((curTab.get() ?? "") == "")
          curTab.set(tabs?[0].id ?? "")
      }
      watch = [resultOptionsGen, currentTab, foundTabsByOptionsGen]
      children = [
        {
          rendObj = ROBJ_WORLD_BLUR_PANEL
          size = static [sw(100), sh(100)]
          stopHotkeys = true
          stopMouse = true
          color = Color(130,130,130)
        }
        settingsMenuCtor({
          key = "settings_menu"
          size = static [sw(70), sh(80)]
          options = optionsValue
          sourceTabs = tabs
          currentTab = currentTab
          buttons = [
            { size=flex(), flow = FLOW_HORIZONTAL, children = menu_params?.leftButtons }
            textButton(loc("Ok"), saveAndApply(close, optionsValue), {
              hotkeys = [
                ["^{0} | J:Start | Esc".subst(JB.B), {action=saveAndApply(closeMenu, optionsValue), description={skip=true}}],
              ],
              skipDirPadNav = true
            })
          ]
          cancelHandler = @() null
        })
      ]
    }
  }
}

return {
  mkSettingsMenuUi
  showSettingsMenu
}
