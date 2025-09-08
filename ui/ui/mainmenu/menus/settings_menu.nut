from "%ui/ui_library.nut" import *

let { eventbus_send } = require("eventbus")
let {apply_video_settings} = require("videomode")
let {apply_audio_settings=@(_fieilds) null} = require_optional("dngsound")
let {isOption} = require("options/options_lib.nut")
let logMenu = require("%sqstd/log.nut")().with_prefix("[SettingsMenu] ")
let { textButton } = require("%ui/components/button.nut")
let JB = require("%ui/control/gui_buttons.nut")
let settingsMenuCtor = require("settingsMenu.nut")
let {showMsgbox} = require("%ui/components/msgbox.nut")
let { save_changed_settings, get_setting_by_blk_path, set_setting_by_blk_path, remove_setting_by_blk_path } = require("settings")
let { renderOptions } = require("%ui/mainMenu/menus/options/render_options.nut")
let { soundOptions } = require("%ui/mainMenu/menus/options/sound_options.nut")
let { cameraFovOption } = require("%ui/mainMenu/menus/options/camera_fov_option.nut")
let { flashlightTipOption } = require("%ui/mainMenu/menus/options/flashlight_tip_option.nut")
let { voiceChatOptions } = require("%ui/mainMenu/menus/options/voicechat_options.nut")
let { optGraphicsQualityPreset } = require("%ui/mainMenu/menus/options/quality_preset_option.nut")
let { onlineSettingUpdated } = require("%ui/options/onlineSettings.nut")
let { missSecondMapHelp, missSecondSarcasm } = require("%ui/mainMenu/menus/options/miss_second_map_help.nut")
let { chocolateRowOption, chocolateColOption } = require("%ui/mainMenu/menus/options/chocolate_matrix_option.nut")

let menuTabsOrder = freeze([
  {id = "Graphics", text=loc("options/graphicsParameters")},
  {id = "Sound", text = loc("sound")},
  {id = "Game", text = loc("options/game")},
  {id = "VoiceChat", text = loc("controls/tab/VoiceChat")},
  {id = "Streaming", text = loc("options/streaming")}
])

let getMenuOptions = @() [flashlightTipOption, cameraFovOption, optGraphicsQualityPreset, missSecondMapHelp,
  missSecondSarcasm, chocolateRowOption, chocolateColOption].extend(renderOptions, soundOptions, voiceChatOptions)

let showSettingsMenu = mkWatched(persist, "showSettingsMenu", false)
let closeMenu = @() showSettingsMenu(false)


let foundTabsByOptionsGen = Watched(0)
let foundTabsByOptionsContainer = {value = []}
let getFoundTabsByOptions = @(...) foundTabsByOptionsContainer.value
function setFoundTabsByOptions(v){
  foundTabsByOptionsContainer.value = v
  foundTabsByOptionsGen(foundTabsByOptionsGen.value+1)
}

let resultOptionsGen = Watched(0)
let resultOptionsContainer = {value = []}
let getResultOptions = @(...) resultOptionsContainer.value
function resultOptions(v){
  resultOptionsContainer.value = v
  resultOptionsGen(resultOptionsGen.value+1)
}

function setResultOptions(...){
  local optionsValue = getMenuOptions()
  let tabsInOptions = {}
  let isAvailableTriggers = optionsValue.filter(@(opt) opt?.isAvailableWatched!=null).map(@(opt) opt.isAvailableWatched)
  optionsValue = optionsValue.filter(@(opt) isOption(opt) && ((opt?.isAvailable==null && opt?.isAvailableWatched==null) || opt?.isAvailable() || opt?.isAvailableWatched.value))

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
    i.subscribe(setResultOptions)
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

let curTab = mkWatched(persist, "curTab")
let currentTab = mkWatched(persist, "currentTab", menuTabsOrder?[0].id)

function checkAndApply(available, val, defVal, blkPath) {
  if (available == null)
    return val

  if (available instanceof Watched)
    available = available.value
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

let convertForBlkByType = {
  float = @(v) v.tofloat()
  integer = @(v) v.tointeger()
  string = @(v) v.tostring()
  bool = @(v) !!v
}
function applyGameSettingsChanges(optionsValue) { 
  local needRestart = false
  let changedFields = []
  foreach (opt in optionsValue) {
    let { blkPath = null } = opt
    if (blkPath) {
      let { defVal = null } = opt
      let isEq = opt.isEqual
      local hasChanges = false
      local val = opt.var.value
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
      let blksettings = [{ blkPath, val, defVal }]
      if ("getMoreBlkSettings" in opt)
        blksettings.extend(opt.getMoreBlkSettings(opt.var.value))
      foreach (setting in blksettings) {
        logMenu(setting.blkPath, get_setting_by_blk_path(setting.blkPath), setting?.defVal, setting.val)
        if (!isEq(get_setting_by_blk_path(setting.blkPath) ?? setting?.defVal, setting.val) && setting.val != null) {
          
          if (type(get_setting_by_blk_path(setting.blkPath)) != type(setting.val))
            remove_setting_by_blk_path(setting.blkPath)
          set_setting_by_blk_path(setting.blkPath, setting.val)
          changedFields.append(setting.blkPath)
          hasChanges = true
        }
      }
      if (hasChanges && opt?.restart)
        needRestart = true
    }
  }
  if (changedFields.len() != 0) {
    logMenu("apply changes", changedFields)
    save_changed_settings(changedFields)
    apply_video_settings(changedFields)
    apply_audio_settings(changedFields)
  }
  return needRestart
}

let saveAndApply = @(onMenuClose, options) function() {
  let needRestart = applyGameSettingsChanges(options)
  onMenuClose()
  eventbus_send("onlineSettings.sendToServer", null)

  if (needRestart) {
    showMsgbox({text=loc("settings/restart_needed")})
  }
}

onlineSettingUpdated.subscribe(@(val) val ? defer(@() applyGameSettingsChanges(getResultOptions())) : null)
applyGameSettingsChanges(getResultOptions())

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
      onDetach = @() curTab(tabs?[0].id ?? "")
      function onAttach(){
        if ((curTab.value ?? "") == "")
          curTab(tabs?[0].id ?? "")
      }
      watch = [resultOptionsGen, currentTab, foundTabsByOptionsGen]
      children = [
        {
          rendObj = ROBJ_WORLD_BLUR_PANEL
          size = [sw(100), sh(100)]
          stopHotkeys = true
          stopMouse = true
          color = Color(130,130,130)
        }
        settingsMenuCtor({
          key = "settings_menu"
          size = [sw(70), sh(80)]
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
