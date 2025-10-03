from "%dngscripts/platform.nut" import is_pc, is_xbox, is_sony, is_nswitch, is_mobile
from "%sqstd/math.nut" import round_by_value
from "%ui/control/formatInputBinding.nut" import buildElems, buildDigitalBindingText, isValidDevice, textListFromAction, getSticksText
from "%ui/mainMenu/menus/controls_online_storage.nut" import setUiClickRumble, setInBattleRumble, isAimAssistExists, setAimAssist, set_stick0_dz, set_stick1_dz, aim_smooth_set, set_use_gamepad
from "%ui/mainMenu/menus/controls_state.nut" import nextGeneration, getActionsList, getActionTags, mkSubTagsFind
from "%ui/fonts_style.nut" import h2_txt, body_txt, fontawesome
from "eventbus" import eventbus_send
from "%sqstd/string.nut" import utf8ToLower
from "%ui/components/textInput.nut" import textInput
from "%ui/components/colors.nut" import TextNormal, ControlBg, BtnBdHover, BtnBdNormal, BtnTextHover, BtnTextNormal, OptionRowBgHover, OptionRowBdHover, MenuRowBgOdd, MenuRowBgEven
from "%ui/components/msgbox.nut" import showMsgbox
from "%ui/components/button.nut" import textButton, button, buttonWithGamepadHotkey
from "%ui/components/scrollbar.nut" import makeVertScroll
import "%ui/components/checkbox.nut" as checkbox
import "%ui/components/slider.nut" as slider
import "%ui/mainMenu/menus/options/optionTextSlider.nut" as mkSliderWithText
import "%ui/mainMenu/menus/settingsHeaderTabs.nut" as settingsHeaderTabs
from "%ui/components/commonComponents.nut" import mkText, fontIconButton
from "%ui/components/text.nut" import dtext
import "console" as console
import "%ui/components/select.nut" as select
import "%ui/helpers/locByPlatform.nut" as locByPlatform
import "DataBlock" as DataBlock
from "dagor.system" import DBGLEVEL
from "%ui/control/active_controls.nut" import ControlsTypes
from "settings" import get_setting_by_blk_path
from "%ui/ui_library.nut" import *
import "onlineStorage" as online_storage
import "dainput2" as dainput
import "control" as control
from "dagor.debug" import logerr
import "%ui/components/fontawesome.map.nut" as fa
import "%ui/control/gui_buttons.nut" as JB

let { showControlsMenu } = require("%ui/mainMenu/menus/menuState.nut")
let { CONTROLS_SETUP_CHANGED_EVENT_ID } = require("%ui/control/controls_generation.nut")
let { safeAreaHorPadding } = require("%ui/options/safeArea.nut")
let { eventTypeLabels } = require("%ui/control/formatInputBinding.nut")
let userInfo = require("%sqGlob/userInfo.nut")
let { onlineSettingUpdated } = require("%ui/options/onlineSettings.nut")
let {format_ctrl_name} = dainput
let {get_action_handle} = dainput
let { BTN_pressed, BTN_pressed_long, BTN_pressed2, BTN_pressed3,
  BTN_released, BTN_released_long, BTN_released_short } = dainput
let { platformId } = require("%dngscripts/platform.nut")

let controlsSettingOnlyForGamePad = Watched(is_xbox || is_sony || is_nswitch || is_mobile)
let { wasGamepad, isGamepad } = require("%ui/control/active_controls.nut")
let { isUiClickRumbleEnabled, isInBattleRumbleEnabled, isAimAssistEnabled, stick0_dz, stick1_dz, aim_smooth, use_gamepad_state } = require("%ui/mainMenu/menus/controls_online_storage.nut")
let { importantGroups, generation, availablePresets, haveChanges, Preset } = require("%ui/mainMenu/menus/controls_state.nut")
let { voiceChatEnabled } = require("%ui/voiceChat/voiceChatGlobalState.nut")

let customSettingsFilter = Watched("")

function menuRowColor(sf, isOdd) {
  return (sf & S_HOVER)
         ? OptionRowBgHover
         : isOdd ? MenuRowBgOdd : MenuRowBgEven
}

function saveConfig(){
  control.save_config()
  if ((!onlineSettingUpdated.get() || userInfo.get()==null) && (get_setting_by_blk_path("disableRemoteNetServices") ?? false)) {
    log("Controls settings won't be applied. Use -config:disableRemoteNetServices:b=yes or login first")
    logerr("Controls settings won't be used on reload.")
  }
}

function resetC0BindingsForOnlyGamepadsPlatforms(defaultPreset) {
  if (controlsSettingOnlyForGamePad.get()) {
    let origBlk = DataBlock()
    dainput.save_user_config(origBlk, true)
    origBlk.removeBlock("c0") 
    origBlk.removeBlock("c2")
    let basePreset = origBlk.getStr("preset", "")
    if (basePreset == "")
      return
    let splitedPresetPath = basePreset.split("~")
    let presetPath = splitedPresetPath?[0] ?? defaultPreset
    let presetPlatform = splitedPresetPath?[1] ?? ""
    let newBasePresetName = $"{presetPath}~{platformId}"
    if (presetPlatform.tolower() == platformId.tolower() || availablePresets.get().findvalue(@(v) v.preset.indexof(newBasePresetName)!=null) == null)
      return
    else {
      origBlk.setStr("preset", newBasePresetName)
      log($"Reset c0 and c2 bindings in customized preset for only gamepad platform, switch {basePreset} to {newBasePresetName}")
    }
    dainput.load_user_config(origBlk)
    saveConfig()
    haveChanges.set(true)
  }
}

console.register_command(function(){
  controlsSettingOnlyForGamePad.set(false)
  let origBlk = DataBlock()
  origBlk.setStr("preset", "content/{0}/config/active_matter.default")
  dainput.load_user_config(origBlk)
  saveConfig()
  haveChanges.set(true)
}, "input.init_pc_preset")

let findSelectedPreset = function(selected) {
  let defaultPreset = dainput.get_user_config_base_preset()
  resetC0BindingsForOnlyGamepadsPlatforms(defaultPreset)
  return availablePresets.get().findvalue(@(v) selected.indexof(v.preset)!=null) ??
         availablePresets.get().findvalue(@(v) ($"{defaultPreset}~{platformId}").indexof(v.preset)!=null) ??
         Preset(defaultPreset)
}
let selectedPreset = Watched(findSelectedPreset(dainput.get_user_config_base_preset()))
let currentPreset =  Watched(selectedPreset.get())
currentPreset.subscribe_with_nasty_disregard_of_frp_update(@(v) selectedPreset.set(findSelectedPreset(v.preset)))
let updateCurrentPreset = @() currentPreset.set(findSelectedPreset(dainput.get_user_config_base_preset()))

let actionRecording = Watched(null)
let configuredAxis = Watched(null)
let configuredButton = Watched(null)



function isGamepadColumn(col) {
  return col == 1
}

function locActionName(name){
  return name!= null ? loc("/".concat("controls", name), name) : null
}

function doesDeviceMatchColumn(dev_id, col) {
  if (dev_id==dainput.DEV_kbd || dev_id==dainput.DEV_pointing)
    return !isGamepadColumn(col)
  if (dev_id==dainput.DEV_gamepad || dev_id==dainput.DEV_joy)
    return isGamepadColumn(col)
  return false
}

let btnEventTypesMap = {
  [BTN_pressed] = "pressed",
  [BTN_pressed_long] = "pressed_long",
  [BTN_pressed2] = "pressed2",
  [BTN_pressed3] = "pressed3",
  [BTN_released] = "released",
  [BTN_released_long] = "released_long",
  [BTN_released_short] = "released_short",
}

let findAllowBindingsSubtags = mkSubTagsFind("allowed_bindings=")
let getAllowedBindingsTypes = memoize(function(ah) {
  let allowedbindings = findAllowBindingsSubtags(ah)
  if (allowedbindings==null)
    return btnEventTypesMap.keys()
  return btnEventTypesMap
    .filter(@(name, _eventType) allowedbindings==null || allowedbindings.indexof(name)!=null)
    .keys()
})


local tabsList = []
local optionsList = []
let isActionDisabledToCustomize = memoize(
  @(action_handler) getActionTags(action_handler).indexof("disabled") != null)

function makeTabsList() {
  local res = [ {id="Options" text=loc("controls/tab/Control")} ]
  let isVoiceChatAvailable = is_pc && voiceChatEnabled.get()
  let bindingTabs = [
    {id="Movement" text=loc("controls/tab/Movement")}
    {id="Weapon" text=loc("controls/tab/Weapon")}
    {id="View" text=loc("controls/tab/View")}
    {id="Squad" text=loc("controls/tab/Squad")}
    {id="Proxy" text=loc("controls/tab/Proxy")}
    {id="Vehicle" text=loc("controls/tab/Vehicle")}
    {id="Plane" text=loc("controls/tab/Plane")}
    {id="Other" text=loc("controls/tab/Other")}
    {id="UI" text=loc("controls/tab/UI")}
    {id="VoiceChat" text=loc("controls/tab/VoiceChat") isEnabled = @() isVoiceChatAvailable }
    {id="Spectator" text=loc("controls/tab/Spectator")}
    {id="Camera" text=loc("controls/tab/Camera", "Free Camera (Dev)") isEnabled = @() DBGLEVEL > 0 }
    {id="Replay" text=loc("controls/tab/Replay", "Replay (Dev)") isEnabled = @() DBGLEVEL > 0 }
  ]

  let hasActions = {}
  let total = dainput.get_actions_count()
  for (local i = 0; i < total; i++) {
    let ah = dainput.get_action_handle_by_ord(i)
    if (!dainput.is_action_internal(ah)){
      let tags = getActionTags(ah)
      foreach(tag in tags)
        hasActions[tag] <- true
    }
  }
  res = res.extend(bindingTabs.filter(@(t) (hasActions?[t.id] ?? false) && (t?.isEnabled?() ?? true)))
    .map(@(v) v.__merge({
      isAvailable = Computed(@() customSettingsFilter.get().len() <= 0)
      unavailableHoverHint = loc("controls/activeSearch")
    }))
  tabsList = res
}
controlsSettingOnlyForGamePad.subscribe(@(_v) makeTabsList())
makeTabsList()


function deleteInputTextBtn() {
  let watch = customSettingsFilter
  if (customSettingsFilter.get().len() <= 0)
    return { watch }
  return {
    watch
    hplace = ALIGN_RIGHT
    vplace = ALIGN_CENTER
    margin = static [0, hdpx(10),0,0]
    children = fontIconButton("icon_buttons/x_btn.svg", @() customSettingsFilter.set(""),
      { padding = hdpx(2) }
    )
  }
}

let searchInputBlock = {
  flow = FLOW_HORIZONTAL
  gap = hdpx(4)
  children = [
    {
      size = static [hdpx(400), SIZE_TO_CONTENT]
      children = textInput(customSettingsFilter, {
        placeholder = loc("search by name")
        textmargin = hdpx(5)
        margin = 0
        onChange = function(value) {
          customSettingsFilter.set(value)
        }
        onEscape = function() {
          if (customSettingsFilter.get() == "")
            set_kb_focus(null)
          customSettingsFilter.set("")
        }
      }.__update(body_txt))
    }
    deleteInputTextBtn
  ]
}


let currentTab = mkWatched(persist, "currentTab", tabsList[0].id)
let selectedBindingCell = mkWatched(persist, "selectedBindingCell")
let selectedAxisCell = mkWatched(persist, "selectedAxisCell")

isGamepad.subscribe_with_nasty_disregard_of_frp_update(function(isGp) {
  if (!isGp || configuredButton.get() != null || actionRecording.get() != null)
    return
  selectedBindingCell.set(null)
  selectedAxisCell.set(null)
})

function isEscape(blk) {
  return blk.getInt("dev", dainput.DEV_none) == dainput.DEV_kbd
      && blk.getInt("btn", 0) == 1
}

let blkPropRemap = {
  minXBtn = "xMinBtn", maxXBtn = "xMaxBtn", minYBtn = "yMinBtn", maxYBtn = "yMaxBtn"
}

let pageAnim =  [
  { prop=AnimProp.opacity, from=0, to=1, duration=0.2, play=true, easing=InOutCubic}
  { prop=AnimProp.opacity, from=1, to=0, duration=0.2, playFadeOut=true, easing=InOutCubic}
]

function startRecording(cell_data) {
  if (cell_data.singleBtn || cell_data.tag == "modifiers")
    dainput.start_recording_bindings_for_single_button()
  else
    dainput.start_recording_bindings(cell_data.ah)
  actionRecording.set(cell_data)
}

function makeBgToggle(initial=true) {
  local showBg = !initial
  function toggleBg() {
    showBg = !showBg
    return showBg
  }
  return toggleBg
}

function set_single_button_analogue_binding(ah, col, actionProp, blk) {
  let stickBinding = dainput.get_analog_stick_action_binding(ah, col)
  let axisBinding = dainput.get_analog_axis_action_binding(ah, col)
  let binding = stickBinding ?? axisBinding
  if (binding != null) {
    binding[actionProp].devId = blk.getInt("dev", 0)
    binding[actionProp].btnId = blk.getInt("btn", 0)
    if (blk.paramCount()+blk.blockCount() == 0) {
      
      binding.devId = dainput.DEV_none
      if (axisBinding != null)
        axisBinding.axisId = 0
      if (stickBinding != null) {
        stickBinding.axisXId = 0
        stickBinding.axisYId = 0
      }
    } else if (binding.devId == dainput.DEV_none && (axisBinding != null || stickBinding != null))
      binding.devId = dainput.DEV_nullstub

    if (binding.devId != dainput.DEV_none && binding.maxVal == 0) 
      binding.maxVal = 1
  }
}

function loadOriginalBindingParametersTo(blk, ah, col) {
  let origBlk = DataBlock()
  dainput.get_action_binding(ah, col, origBlk)

  let actionType = dainput.get_action_type(ah)

  blk.setReal("dzone", origBlk.getReal("dzone", 0.0))
  blk.setReal("nonlin", origBlk.getReal("nonlin", 0.0))
  blk.setReal("maxVal", origBlk.getReal("maxVal", 1.0))
  if ((actionType & dainput.TYPEGRP__MASK) == dainput.TYPEGRP_STICK)
    blk.setReal("sensScale", origBlk.getReal("sensScale", 1.0))
}

function loadPreviousBindingParametersTo(blk, ah, col) {
  let prevBinding = dainput.get_digital_action_binding(ah, col)

  let actionType = dainput.get_action_type(ah)

  if ((actionType & dainput.TYPEGRP__MASK) == dainput.TYPEGRP_DIGITAL)
    blk.setBool("stickyToggle", prevBinding.stickyToggle)
}

function checkRecordingFinished() {
  if (dainput.is_recording_complete()) {
    let cellData = actionRecording.get()
    actionRecording.set(null)
    let ah = cellData?.ah

    let blk = DataBlock()
    let ok = dainput.finish_recording_bindings(blk)

    let devId = blk.getInt("dev", dainput.DEV_none)
    if (ok && ah!=null && devId!=dainput.DEV_none && !isEscape(blk)) {
      let col = cellData?.column
      if (doesDeviceMatchColumn(devId, col)) {
        gui_scene.clearTimer(callee())

        local checkConflictsBlk
        if (cellData.singleBtn) {
          checkConflictsBlk = DataBlock()
          dainput.get_action_binding(ah, col, checkConflictsBlk)
          let btnBlk = checkConflictsBlk.addBlock(blkPropRemap?[cellData.actionProp] ?? cellData.actionProp)
          btnBlk.setParamsFrom(blk)
        }
        else {
          checkConflictsBlk = blk
        }

        function applyBinding() {
          if (cellData.singleBtn) {
            set_single_button_analogue_binding(ah, col, cellData.actionProp, blk)
          }
          else if (cellData.tag == "modifiers") {
            let binding = dainput.get_analog_stick_action_binding(ah, cellData.column)
                          ?? dainput.get_analog_axis_action_binding(ah, cellData.column)

            let btn = dainput.SingleButtonId()
            btn.devId = devId
            btn.btnId = blk.getInt("btn", 0)
            binding.mod = [btn]
          }
          else {
            loadOriginalBindingParametersTo(blk, ah, col)
            loadPreviousBindingParametersTo(blk, ah, col)
            dainput.set_action_binding(ah, col, blk)
            let binding = dainput.get_digital_action_binding(ah, col)
            if (binding?.eventType)
              binding.eventType = getAllowedBindingsTypes(ah)[0]
          }
          nextGeneration()
          haveChanges.set(true)
        }

        let conflicts = dainput.check_bindings_conflicts(ah, checkConflictsBlk)
        if (conflicts == null) {
          applyBinding()
        } else {
          let actionNames = conflicts.map(@(a) dainput.get_action_name(a.action))
          let localizedNames = actionNames.map(@(a) loc($"controls/{a}"))
          let actionsText = ", ".join(localizedNames)
          let messageText = loc("controls/binding_conflict_prompt", "This conflicts with {actionsText}. Bind anyway?", {
            actionsText = actionsText
          })
          showMsgbox({
            text = messageText
            buttons = [
              { text = loc("Yes"), action = applyBinding }
              { text = loc("No") }
            ]
          })
        }
      } else {
        startRecording(cellData)
      }
    }
  }
}


function cancelRecording() {
  gui_scene.clearTimer(checkRecordingFinished)
  actionRecording.set(null)

  let blk = DataBlock()
  dainput.finish_recording_bindings(blk)
}



let mediumText = @(text, params={}) dtext(text, {color = TextNormal,}.__update(body_txt, params))

function recordingWindow() {
  
  local text
  let cellData = actionRecording.get()
  let name = cellData?.name
  if (cellData) {
    let actionType = dainput.get_action_type(cellData.ah)
    if ( (actionType & dainput.TYPEGRP__MASK) == dainput.TYPEGRP_DIGITAL
          || cellData.actionProp!=null || cellData.tag == "modifiers") {
      if (isGamepadColumn(cellData.column))
        text = loc("controls/recording_digital_gamepad", "Press a gamepad button to bind action to")
      else
        text = loc("controls/recording_digital_keyboard", "Press a button on keyboard to bind action to")
    }
    else if (isGamepadColumn(cellData.column)) {
      text = loc("controls/recording_analogue_joystick", "Move stick or press button to bind action to")
    } else {
      text = loc("controls/recording_analogue_mouse", "Move mouse to bind action")
    }
  }
  return {
    size = flex()
    rendObj = ROBJ_WORLD_BLUR_PANEL
    fillColor = Color(0,0,0,225)
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    stopHotkeys = true
    stopMouse = true
    cursor = null
    hotkeys = [["^Esc", cancelRecording]]
    onDetach = cancelRecording
    watch = actionRecording
    flow = FLOW_VERTICAL
    gap = fsh(8)
    children = [
      {size=static [0, flex(3)]}
      dtext(locActionName(name), {color = Color(100,100,100)}.__update(h2_txt))
      mediumText(text, {
        function onAttach() {
          gui_scene.clearTimer(checkRecordingFinished)
          gui_scene.setInterval(0.1, checkRecordingFinished)
        }
        function onDetach() {
          gui_scene.clearTimer(checkRecordingFinished)
        }
      })
      {size=static [0, flex(5)]}
    ]
  }
}

function saveChanges() {
  saveConfig()
  haveChanges.set(false)
}

function applyPreset(text, target=null) {
  function doReset() {
    if (target)
      dainput.reset_user_config_to_preset(target.preset, false)
    else
      control.reset_to_default()
    saveChanges()
    nextGeneration()
  }

  showMsgbox({
    text
    children = dtext(loc("controls/preset", {
      preset = target?.name ?? selectedPreset.get().name
    }), {margin = hdpx(50)})
    buttons = [
      { text = loc("Yes"), action = doReset }
      { text = loc("No") }
    ]
  })
}

function resetToDefault() {
  let text = loc("controls/resetToDefaultsConfirmation")
  applyPreset(text)
}

function changePreset(target) {
  let text = loc("controls/changeControlsPresetConfirmation")
  applyPreset(text, target)
}

function clearBinding(cellData){
  haveChanges.set(true)
  if (cellData.singleBtn) {
    set_single_button_analogue_binding(cellData.ah, cellData.column, cellData.actionProp, DataBlock())
  } else if (cellData.tag == "modifiers") {
    let binding = dainput.get_analog_stick_action_binding(cellData.ah, cellData.column)
                  ?? dainput.get_analog_axis_action_binding(cellData.ah, cellData.column)
    binding.mod = []
  } else {
    let blk = DataBlock()
    loadOriginalBindingParametersTo(blk, cellData.ah, cellData.column)
    dainput.set_action_binding(cellData.ah, cellData.column, blk)
  }
}

function discardChanges() {
  if (!haveChanges.set)
    return
  control.restore_saved_config()
  nextGeneration()
  haveChanges.set(false)
}

let btnPadding = static [0, hdpx(32)]

function actionButtons() {
  local children = null
  let cellData = selectedBindingCell.get()
  if (cellData != null) {
    let actionType = dainput.get_action_type(cellData.ah)
    let actionTypeGroup = actionType & dainput.TYPEGRP__MASK

    if (!isActionDisabledToCustomize(cellData.ah)) {
      children = [
        buttonWithGamepadHotkey(mkText(loc("controls/clearBinding"), { padding = btnPadding }.__merge(body_txt)),
          function() {
            clearBinding(selectedBindingCell.get())
            nextGeneration()
          },
          static {
            hotkeys = [["^J:X", { description = { skip = true } }]]
            skipDirPadNav = true
            size = [SIZE_TO_CONTENT, hdpx(50)]
          })
      ]
      if (actionTypeGroup == dainput.TYPEGRP_AXIS || actionTypeGroup == dainput.TYPEGRP_STICK) {
        children.append(buttonWithGamepadHotkey(mkText(loc("controls/axisSetup"), { padding = btnPadding }.__merge(body_txt)),
          @() configuredAxis.set(selectedBindingCell.get()),
          static {
            hotkeys = [["^{0}".subst(JB.A), { description = { skip = true } }]]
            skipDirPadNav = true
            size = [SIZE_TO_CONTENT, hdpx(50)]
          })
        )
      }
      else if (actionTypeGroup == dainput.TYPEGRP_DIGITAL) {
        children.append(
          buttonWithGamepadHotkey(mkText(loc("controls/buttonSetup"), { padding = btnPadding }.__merge(body_txt)),
            @() configuredButton.set(selectedBindingCell.get()),
            static {
              hotkeys = [["^J:Y", { description = { skip = true } }]]
              skipDirPadNav = true
              size = [SIZE_TO_CONTENT, hdpx(50)]
            })

          buttonWithGamepadHotkey(mkText(loc("controls/bindBinding"), { padding = btnPadding }.__merge(body_txt)),
            @() startRecording(selectedBindingCell.get()),
            static {
              hotkeys = [["^{0}".subst(JB.A), { description = { skip = true } }]]
              skipDirPadNav = true
              size = [SIZE_TO_CONTENT, hdpx(50)]
            })
          )
      }
    }
  }
  return {
    watch = selectedBindingCell
    flow = FLOW_HORIZONTAL
    children
  }
}

function collectBindableColumns() {
  let nColumns = dainput.get_actions_binding_columns()
  let colRange = []
  for (local i=0; i<nColumns; ++i) {
    if (!controlsSettingOnlyForGamePad.get() || isGamepadColumn(i))
      colRange.append(i)
  }
  return colRange
}

function getNotBoundActions() {
  let importantTabs = importantGroups.get()

  let colRange = collectBindableColumns()
  let notBoundActions = {}

  for (local i = 0; i < dainput.get_actions_count(); ++i) {
    let ah = dainput.get_action_handle_by_ord(i)
    if (dainput.is_action_internal(ah))
      continue

    let actionGroups = getActionTags(ah)
    local isActionInImportantGroup = false
    foreach (actionGroup in actionGroups) {
      if (importantTabs.indexof(actionGroup) != null && !isActionDisabledToCustomize(ah))
        isActionInImportantGroup = true
    }

    if (actionGroups.indexof("not_important") != null)
      isActionInImportantGroup = false

    if (actionGroups.indexof("important") != null)
      isActionInImportantGroup = true

    if (!isActionInImportantGroup)
      continue

    local someBound = false
    let atFlag = dainput.get_action_type(ah) & dainput.TYPEGRP__MASK
    if (atFlag == dainput.TYPEGRP_DIGITAL) {
      let bindings = colRange.map(@(col, _) dainput.get_digital_action_binding(ah, col))
      foreach (val in bindings)
        if (isValidDevice(val.devId) || val.devId == dainput.DEV_nullstub) {
          someBound = true
          break
        }
    }
    else if (dainput.TYPEGRP_AXIS == atFlag) {
      let axisBinding = colRange.map(@(col, _) dainput.get_analog_axis_action_binding(ah, col))
      foreach (val in axisBinding) {
        if (val.devId == dainput.DEV_pointing || val.devId == dainput.DEV_joy || val.devId == dainput.DEV_gamepad || val.devId == dainput.DEV_nullstub) {
          
          someBound = true
          break
        }

        
        if (isValidDevice(val.minBtn.devId) && isValidDevice(val.maxBtn.devId)) {
          someBound = true
          break
        }
      }
    }
    else if (dainput.TYPEGRP_STICK == atFlag) {
      let stickBinding = colRange.map(@(col, _) dainput.get_analog_stick_action_binding(ah, col))
      foreach (val in stickBinding) {
        if (val.devId == dainput.DEV_pointing || val.devId == dainput.DEV_joy || val.devId == dainput.DEV_gamepad || val.devId == dainput.DEV_nullstub) {
          someBound = true
          break
        }
        if (isValidDevice(val.maxXBtn.devId) && isValidDevice(val.minXBtn.devId)
          && isValidDevice(val.maxYBtn.devId) && isValidDevice(val.minYBtn.devId)) {
          someBound = true
          break
        }
      }
    }

    if (!someBound) {
      let actionName = dainput.get_action_name(ah)
      let actionGroup = actionGroups?[0]
      if (actionGroup==null)
        continue
      if (!notBoundActions?[actionGroup])
        notBoundActions[actionGroup] <- { header = loc($"controls/tab/{actionGroup}"), controls = [] }

      notBoundActions[actionGroup].controls.append(loc($"controls/{actionName}", actionName))
    }
  }

  if (notBoundActions.len() == 0)
    return null

  let ret = []
  foreach (action in notBoundActions) {
    ret.append($"\n\n{action.header}:\n")
    ret.append(", ".join(action.controls))
  }

  return "".join(ret)
}

function onDiscardChanges() {
  showMsgbox({
    text = loc("settings/onCancelChangingConfirmation")
    buttons = [
      { text=loc("Yes"), action = discardChanges }
      { text=loc("No") }
    ]
  })
}

let onClose = @() showControlsMenu.set(false)

function mkWindowButtons(width) {
  function onApply() {
    let notBoundActions = is_pc ? getNotBoundActions() : null
    if (notBoundActions == null) {
      saveChanges()
      onClose()
      return
    }

    showMsgbox({
      text = "".concat(loc("controls/warningUnmapped"), notBoundActions)
      buttons = [
        { text=loc("Ok"),
          action = function() {
            saveChanges()
            onClose()
          }
        }
        { text = loc("Cancel"), action = @() null }
      ]
    })
  }

  return @() {
    watch = haveChanges
    size = [width, SIZE_TO_CONTENT]
    vplace = ALIGN_BOTTOM
    hplace = ALIGN_RIGHT
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    rendObj = ROBJ_SOLID
    color = ControlBg
    children = wrap([
      {
        flow = FLOW_HORIZONTAL
        children = [
          textButton(loc("controls/btnResetToDefaults"), resetToDefault)
          haveChanges.get() ? textButton(loc("mainmenu/btnDiscard"), onDiscardChanges) : null
        ]
      }
      {
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        halign = ALIGN_RIGHT
        children = [
          actionButtons
          buttonWithGamepadHotkey(mkText(loc("mainmenu/btnApply"), { padding = btnPadding }.__merge(body_txt)),
            onApply,
            static {
              hotkeys = [["^{0} | J:Start | Esc".subst(JB.B), { description= { skip = true } }]]
              skipDirPadNav = true
              size = [SIZE_TO_CONTENT, hdpx(50)]
            })
        ]
      }
    ], {width, flowElemProto = {size = FLEX_H halign = ALIGN_RIGHT, padding = fsh(0.5) }})
  }
}


function bindingTextFunc(text) {
  return {
    text
    color = TextNormal
    rendObj = ROBJ_TEXT
    padding = hdpx(4)
  }.__update(body_txt)
}


function mkActionRowLabel(name, group=null){
  return {
    rendObj = ROBJ_TEXT
    color = TextNormal
    text = locActionName(name)
    margin = static [0, fsh(1), 0, 0]
    size = static [flex(1.5), SIZE_TO_CONTENT]
    halign = ALIGN_RIGHT
    group
  }.__update(body_txt)
}

function mkActionRowCells(label, columns){
  let children = [label].extend(columns)
  if (columns.len() < 2)
    children.append({size=static [flex(0.75), 0]})
  return children
}

function makeActionRow(_ah, name, columns, xmbNode, showBgGen) {
  let group = ElemGroup()
  let isOdd = showBgGen()
  let label = mkActionRowLabel(name, group)
  let children = mkActionRowCells(label, columns)
  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    return {
      watch = stateFlags
      onElemState = @(s) stateFlags.set(s)
      xmbNode
      key = name
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      behavior = Behaviors.Button
      skipDirPadNav = true
      children
      rendObj = ROBJ_BOX
      fillColor = menuRowColor(sf, isOdd)
      borderWidth = (sf & S_HOVER) ? [hdpx(2), 0] : 0
      borderColor = OptionRowBdHover
      group
    }
  }
}


let bindingColumnCellSize = [flex(1), fontH(240)]

function isCellSelected(cell_data, selection) {
  let selected = selection.get()
  return (selected!=null) && selected.column==cell_data.column && selected.ah==cell_data.ah
    && selected.actionProp==cell_data.actionProp && selected.tag==cell_data.tag
}

function showDisabledMsgBox(){
  return showMsgbox({
    text = loc("controls/bindingDisabled")
    buttons = [
      { text = loc("Ok")}
    ]
  })
}


function bindedComp(elemList, group=null){
  return {
     group = group ?? ElemGroup()
     behavior = Behaviors.Marquee
     scrollOnHover = true
     size = SIZE_TO_CONTENT
     maxWidth = pw(100)
     flow = FLOW_HORIZONTAL
     valign = ALIGN_CENTER
     children = buildElems(elemList, {textFunc = bindingTextFunc, eventTypesAsTxt = true})
  }
}


function bindingCell(ah, column, action_prop, list, tag, selection, name=null, xmbNode=null) {
  let singleBtn = action_prop!=null
  let cellData = {
    ah=ah, column=column, actionProp=action_prop, singleBtn=singleBtn, tag=tag, name=name
  }

  let group = ElemGroup()
  let isForGamepad = isGamepadColumn(column)

  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    let hovered = (sf & S_HOVER)
    let selected = isCellSelected(cellData, selection)
    let isBindable = isForGamepad || !isGamepad.get()
    return {
      watch = [stateFlags, selection, isGamepad]
      onElemState = @(s) stateFlags.set(s)
      size = bindingColumnCellSize

      behavior = isBindable ? Behaviors.Button : null
      group
      xmbNode = isBindable ? xmbNode : null
      padding = fsh(0.5)

      children = {
        rendObj = ROBJ_BOX
        fillColor = selected ? Color(0,0,0,255)
                  : hovered ? Color(40, 40, 40, 80)
                  : Color(0, 0, 0, 40)
        borderWidth = selected ? hdpx(2) : 0
        borderColor = TextNormal
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        clipChildren = true

        size = flex()
        children = bindedComp(list, group)
      }

      function onDoubleClick() {
        let actionType = dainput.get_action_type(ah)
        if (isActionDisabledToCustomize(ah))
          return showDisabledMsgBox()

        if ((actionType & dainput.TYPEGRP__MASK) == dainput.TYPEGRP_DIGITAL
          || cellData.singleBtn || cellData.tag == "modifiers" || cellData.tag == "axis")
          startRecording(cellData)
        else
          configuredAxis.set(cellData)
      }

      onClick = isGamepad.get() ? null : isActionDisabledToCustomize(ah) ? showDisabledMsgBox : @() selection.set(cellData)
      onHover = isGamepad.get() ? @(on) selection.set(on ? cellData : null) : null

      function onDetach() {
        if (isCellSelected(cellData, selection))
          selection.set(null)
      }
    }
  }
}

let colorTextHdr = Color(120,120,120)
function bindingColHeader(typ){
  return {
    size = bindingColumnCellSize
    rendObj = ROBJ_TEXT
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    text = loc("/".concat("controls/type", platformId, typ),typ)
    color = colorTextHdr
  }
}


function mkBindingsHeader(colRange){
  let cols = colRange.map(@(v) bindingColHeader(isGamepadColumn(v)
                                                  ? loc("controls/type/pc/gamepad")
                                                  : loc("controls/type/pc/keyboard")))
  return {
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    children = mkActionRowCells(mkActionRowLabel(null), cols)
    valign = ALIGN_CENTER
    gap = fsh(2)
    rendObj = ROBJ_SOLID
    color = Color(0,0,0)
  }
}

let emptyBlockText = mkText(loc("controls/activeSearchEmpty"), {
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
}.__merge(h2_txt))

function bindingsPage(section_name, nameFilter) {
  let scrollHandler = ScrollHandler()
  let filteredActions = getActionsList().filter(function(ah) {
    if (nameFilter.len() > 0)
      return utf8ToLower(locActionName(dainput.get_action_name(ah))).contains(utf8ToLower(nameFilter))
    else
      return getActionTags(ah).indexof(section_name) != null
    })
  let xmbRootNode = XmbContainer()


  return function() {
    let colRange = collectBindableColumns()
    let toggleBg = makeBgToggle()

    let actionRows = []
    let header = mkBindingsHeader(colRange)

    foreach (_aidx, ah in filteredActions) {
      let actionName = dainput.get_action_name(ah)
      let actionType = dainput.get_action_type(ah)
      let atFlag = actionType & dainput.TYPEGRP__MASK
      if (dainput.TYPEGRP_DIGITAL == atFlag) {
        let bindings = colRange.map(@(col) dainput.get_digital_action_binding(ah, col))
        let colTexts = bindings.map(buildDigitalBindingText)
        let colComps = colTexts.map(@(col_text, idx) bindingCell(ah, colRange[idx], null, col_text, null, selectedBindingCell, actionName, XmbNode()))
        actionRows.append(makeActionRow(ah, actionName, colComps, XmbNode(), toggleBg))
      }
      else if (dainput.TYPEGRP_AXIS == atFlag || dainput.TYPEGRP_STICK ==atFlag) {
        let colTexts = colRange.map(@(col, _) textListFromAction(actionName, col))
        let colComps = colTexts.map(@(col_text, idx) bindingCell(ah, colRange[idx], null, col_text, null, selectedBindingCell, actionName, XmbNode()))
        actionRows.append(makeActionRow(ah, actionName, colComps, XmbNode(), toggleBg))
      }
    }
    local actionsList = actionRows
    if (nameFilter.len() > 0)
      actionsList = [].extend(actionRows, optionsList.filter(@(v) utf8ToLower(v?().key ?? "").contains(nameFilter)))
    let bindingsArea = makeVertScroll({
      xmbNode = xmbRootNode
      flow = FLOW_VERTICAL
      size = FLEX_H
      clipChildren = true
      children = actionsList.len() > 0 ? actionsList : emptyBlockText
      scrollHandler
    })

    return {
      watch = generation
      size = flex()
      padding = static [fsh(1), 0]
      flow = FLOW_VERTICAL
      key = section_name
      animations = pageAnim
      children = [is_pc ? header : null, bindingsArea]
    }
  }
}

function optionRowContainer(children, isOdd, params) {
  let stateFlags = Watched(0)
  return function() {
    let sf = stateFlags.get()
    return {
      watch = stateFlags
      size = FLEX_H
      onElemState = @(s) stateFlags.set(s)
      children = params.__merge({
        rendObj = ROBJ_SOLID
        size = FLEX_H
        flow = FLOW_HORIZONTAL
        gap = static fsh(2)
        valign = ALIGN_CENTER
        skipDirPadNav = true
        color = menuRowColor(sf, isOdd)
        padding = static [0, fsh(2)]
        children = children
      })
    }
  }
}

function optionRow(labelText, comp, isOdd) {
  let label = {
    rendObj = ROBJ_TEXT
    color = TextNormal
    text = labelText
    margin = fsh(1)
    size = static [flex(1), SIZE_TO_CONTENT]
    
    halign = ALIGN_RIGHT
  }.__update(body_txt)

  let children = [
    label
    {
      size = [flex(), fontH(200)]
      
      halign = ALIGN_LEFT
      valign = ALIGN_CENTER
      children = comp
    }
  ]

  return optionRowContainer(children, isOdd, {key=labelText})
}

let invertFields = {
  [0] = "axisXinv",
  [1] = "axisYinv",
  [-1] = "invAxis",
}

function invertCheckbox(action_names, column, axis) {
  if (type(action_names) != "array")
    action_names = [action_names]

  let bindings = action_names.map(function(aname) {
    let ah = dainput.get_action_handle(aname, 0xFFFF)
    return dainput.get_analog_stick_action_binding(ah, column)
        ?? dainput.get_analog_axis_action_binding(ah, column)
  }).filter(@(b) b!=null)

  if (!bindings.len())
    return null

  let curInverses = bindings.map(@(b) b[invertFields[axis]])

  let valAnd = curInverses.reduce(@(a,b) a && b, true)
  let valOr = curInverses.reduce(@(a,b) a || b, false)

  let val = Watched((valAnd == valOr) ? valAnd : null)

  function setValue(new_val) {
    val.set(new_val)
    foreach (b in bindings)
      b[invertFields[axis]] = new_val
    haveChanges.set(true)
  }

  return checkbox(val, null, { setValue = setValue, override = { size = flex(), valign = ALIGN_CENTER } useHotkeys=true xmbNode=XmbNode()})
}
let mkRounded = @(val) round_by_value(val, 0.01)

function axisSetupSlider(action_names, column, prop, params) {
  let group = ElemGroup()
  if (type(action_names) != "array")
    action_names = [action_names]

  let bindings = action_names.map(function(aname) {
    let ah = dainput.get_action_handle(aname, 0xFFFF)
    return dainput.get_analog_stick_action_binding(ah, column)
        ?? dainput.get_analog_axis_action_binding(ah, column)
  }).filter(@(binding) binding!=null)

  if (!bindings.len())
    return null

  let curSens = bindings.map(@(b) b[prop]).filter(@(prp) prp!=null)
  if (!curSens.len())
    return null
  let val = Watched(curSens[0]) 
  let opt = params.__merge({
    var = val,
    function setValue(new_val) {
      val.set(new_val)
      foreach (b in bindings)
        b[prop] = new_val
      haveChanges.set(true)
    }
  })
  return mkSliderWithText(opt, group, XmbNode(), params?.morphText ?? mkRounded)
}


let sensRanges = [
  {min = 0.05, max = 5.0, step = 0.05} 
  {min = 0.05, max = 5.0, step = 0.05} 
  {min = 0.05, max = 5.0, step = 0.05} 
]

function sensitivitySlider(action_names, column) {
  let params = sensRanges[column].__merge({

  })
  return axisSetupSlider(action_names, column, "sensScale", params)
}

function sensMulSlider(prop) {
  let sensScale = control.get_sens_scale()
  let var = Watched(sensScale[prop])
  let opt = {
    var,
    function setValue(new_val) {
      var.set(new_val)
      sensScale[prop] = new_val
      
    }
    min = 0.05
    max = 5.0
    step = 0.05
  }
  return mkSliderWithText(opt, null, XmbNode())
}


function smoothMulSlider(action_name) {
  let act = get_action_handle(action_name, 0xFFFF)
  if (act == 0xFFFF)
    return null
  let opt = {
    var = aim_smooth
    min = 0.0
    max = 0.5
    step = 0.05
    function setValue(new_val) {
      aim_smooth_set(new_val)
      dainput.set_analog_stick_action_smooth_value(act, new_val)
    }
  }
  return mkSliderWithText(opt, null, XmbNode())
}


function showDeadZone(val){
  return "{0}%".subst(round_by_value(val*100, 0.5))
}

let showRelScale = @(val) "{0}%".subst(round_by_value(val*10, 0.5))

const minDZ = 0.0
const maxDZ = 0.4
const stepDZ = 0.01
function deadZoneScaleSlider(val, setVal){
  let opt = {var = val, min = minDZ, max = maxDZ, step=stepDZ, scaling = slider.scales.linear, setValue = setVal}
  return mkSliderWithText(opt, null, XmbNode(), showDeadZone)
}
let isUserConfigCustomized = Watched(false)
function checkUserConfigCustomized(){
  isUserConfigCustomized.set(dainput.is_user_config_customized())
}

function updateAll(...) { updateCurrentPreset(); checkUserConfigCustomized()}
generation.subscribe_with_nasty_disregard_of_frp_update(updateAll)
haveChanges.subscribe_with_nasty_disregard_of_frp_update(updateAll)
let showPresetsSelect = Computed(@() availablePresets.get().len()>0)

let onClickCtor = @(p, _idx) @() p.preset != selectedPreset.get().preset || isUserConfigCustomized.get() ? changePreset(p) : null 
let isCurrent = @(p, _idx) p.preset==selectedPreset.get().preset
let textCtor = @(p, _idx, _stateFlags) p?.name!=null ? loc(p?.name) : null
let selectPreset = select({state=selectedPreset, options=availablePresets.get(), onClickCtor, isCurrent, textCtor})

let currentControls = @(){
  size = flex()
  watch = [showPresetsSelect, isUserConfigCustomized]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  gap = {size = static [hdpx(10),0]}
  children = showPresetsSelect.get()
            ? [selectPreset].append(isUserConfigCustomized.get()
                ? dtext(loc("controls/modifiedControls"), {color = TextNormal})
                : null)
            : null
}
function pollSettings() {
  if (isUserConfigCustomized.get())
    return
  updateAll()
}

let controlsTypesMap = {
  [ControlsTypes.AUTO] = loc("options/auto"),
  [ControlsTypes.KB_MOUSE] = loc("controls/type/pc/keyboard"),
  [ControlsTypes.GAMEPAD] = loc("controls/type/pc/gamepad")
}

function options() {
  let onlyGamePad = controlsSettingOnlyForGamePad.get()
  let toggleBg = makeBgToggle()
  let showGamepadOpts = wasGamepad.get()
  let isGyroAvailable = availablePresets.get().findvalue(
    @(v) (v?.name.indexof(loc("".concat("gyro~",platformId))) != null)
  )
  let children = [
    [true, loc("controls/curControlPreset"), currentControls],
    [!onlyGamePad, loc("controls/pc/useGamepad"),
      select({state=use_gamepad_state, options=[ControlsTypes.AUTO, ControlsTypes.KB_MOUSE, ControlsTypes.GAMEPAD],
        onClickCtor=@(p, _idx) @() p != use_gamepad_state.get() ? set_use_gamepad(p) : null,

        textCtor=@(p, _idx, _stateFlags) controlsTypesMap?[p] ?? loc(p)})
    ],
    [!onlyGamePad, loc("controls/mouseAimXInvert"), invertCheckbox(["Human.Aim", "Vehicle.Aim"], 0, 0)],
    [!onlyGamePad, loc("controls/mouseAimYInvert"), invertCheckbox(["Human.Aim", "Vehicle.Aim"], 0, 1)],
    [isGyroAvailable, locByPlatform("controls/gyroAimXInvert"), invertCheckbox(["Human.AimDelta", "Vehicle.AimDelta"], 1, 0)],
    [isGyroAvailable, locByPlatform("controls/gyroAimYInvert"), invertCheckbox(["Human.AimDelta", "Vehicle.AimDelta"], 1, 1)],
    [showGamepadOpts, loc("controls/joyAimXInvert"), invertCheckbox(["Human.Aim", "Vehicle.Aim"], 1, 0)],
    [showGamepadOpts, loc("controls/joyAimYInvert"), invertCheckbox(["Human.Aim", "Vehicle.Aim"], 1, 1)],
    [!onlyGamePad, loc("controls/mouseAimSensitivity"), sensitivitySlider(["Human.Aim", "Vehicle.Aim"], 0)],
    [isGyroAvailable, locByPlatform("controls/gyroAimSensitivity"), sensitivitySlider(["Human.AimDelta", "Vehicle.AimDelta"], 1)],
    [showGamepadOpts, loc("controls/joyAimSensitivity"), sensitivitySlider(["Human.Aim", "Vehicle.Aim"], 1)],
    [true, loc("controls/sensScale/humanAiming"), sensMulSlider("humanAiming")],
    [DBGLEVEL > 0, loc("controls/sensScale/humanTpsCam"), sensMulSlider("humanTpsCam")],
    [DBGLEVEL > 0, loc("controls/sensScale/humanFpsCam"), sensMulSlider("humanFpsCam")],
    [true, loc("controls/sensScale/vehicleCam"), sensMulSlider("vehicleCam")],
    [showGamepadOpts, loc("gamepad/stick0_deadzone"), deadZoneScaleSlider(stick0_dz, set_stick0_dz)],
    [showGamepadOpts, loc("gamepad/stick1_deadzone"), deadZoneScaleSlider(stick1_dz, set_stick1_dz)],
    [showGamepadOpts && isAimAssistExists,
      loc("options/aimAssist"),
      checkbox(isAimAssistEnabled, null,
        { setValue = setAimAssist, useHotkeys = true, override={size=flex() valign = ALIGN_CENTER xmbNode=XmbNode()}})
    ],
    [showGamepadOpts, loc("controls/uiClickRumble"),
      checkbox(isUiClickRumbleEnabled, null,
        { setValue = setUiClickRumble, override = { size = flex(), valign = ALIGN_CENTER } useHotkeys=true xmbNode=XmbNode()})],
    [showGamepadOpts, loc("controls/inBattleRumble"),
      checkbox(isInBattleRumbleEnabled, null,
        { setValue = setInBattleRumble, override = { size = flex(), valign = ALIGN_CENTER } useHotkeys=true xmbNode=XmbNode()})],

    [true, loc("controls/aimSmooth"), smoothMulSlider("Human.Aim")],
  ].map(@(v) v[0] ? optionRow.call(null, v[1],v[2], toggleBg()) : null)

  optionsList = children
  let bindingsArea = makeVertScroll({
    flow = FLOW_VERTICAL
    size = FLEX_H
    clipChildren = true
    children
  })

  return {
    key = "options"
    size = flex()
    flow = FLOW_VERTICAL
    onAttach = function() {
      gui_scene.clearTimer(pollSettings)
      gui_scene.setInterval(0.5, pollSettings) 
    }
    onDetach = @() gui_scene.clearTimer(pollSettings)
    watch = [controlsSettingOnlyForGamePad, wasGamepad]
    xmbNode = XmbContainer()
    children = [bindingsArea]
    animations = pageAnim
  }
}


function sectionHeader(text) {
  return optionRowContainer({
    rendObj = ROBJ_TEXT
    text
    color = TextNormal
    padding = static [fsh(3), fsh(1), fsh(1)]
  }.__update(h2_txt), false, {
    halign = ALIGN_CENTER
  })
}


function axisSetupWindow() {
  let cellData = configuredAxis.get()
  let stickBinding = dainput.get_analog_stick_action_binding(cellData.ah, cellData.column)
  let axisBinding = dainput.get_analog_axis_action_binding(cellData.ah, cellData.column)
  let binding = stickBinding ?? axisBinding
  let actionTags = getActionTags(cellData.ah)

  let actionName = dainput.get_action_name(cellData.ah)
  let actionType = dainput.get_action_type(cellData.ah)

  let title = {
    rendObj = ROBJ_TEXT
    color = TextNormal
    text = loc($"controls/{actionName}", actionName)
    margin = fsh(2)
  }.__update(h2_txt)

  function buttons() {
    let children = []
    if (selectedAxisCell.get())
      children.append(
        textButton(loc("controls/bindBinding"),
          function() { startRecording(selectedAxisCell.get()) },
          { hotkeys = [["^{0}".subst(JB.A), { description = loc("controls/bindBinding") }]] })
        textButton(loc("controls/clearBinding"),
          function() {
            clearBinding(selectedAxisCell.get())
            nextGeneration()
          },
          { hotkeys = [["^J:X"]] })
       )

    children.append(textButton(loc("mainmenu/btnOk", "OK"),
      function() { configuredAxis.set(null) },
      { hotkeys = [["^{0} | J:Start | Esc".subst(JB.B), { description={skip=true} }]] }))

    return {
      watch = selectedAxisCell

      size = FLEX_H
      flow = FLOW_HORIZONTAL
      halign = ALIGN_RIGHT
      children
    }
  }

  let modifiersList = []
  for (local i=0, n=binding.modCnt; i<n; ++i) {
    let mod = binding.mod[i]
    modifiersList.append(format_ctrl_name(mod.devId, mod.btnId))
    if (i < n-1)
      modifiersList.append("+")
  }

  local toggleBg = makeBgToggle()
  let rows = [
    optionRow(loc("Modifiers"), bindingCell(cellData.ah, cellData.column, null, modifiersList, "modifiers", selectedAxisCell), toggleBg())
  ]

  local axisBindingTextList
  if (stickBinding) {
    axisBindingTextList = getSticksText(stickBinding)
  } else if (axisBinding) {
    axisBindingTextList = format_ctrl_name(axisBinding.devId, axisBinding.axisId, false)
  }

  toggleBg = makeBgToggle()

  rows.append(
    sectionHeader(loc("controls/analog-axis-section", "Analog axis"))

    optionRow(loc("controls/analog/axis", "Axis"), bindingCell(cellData.ah, cellData.column, null, axisBindingTextList ? [axisBindingTextList] : [], "axis", selectedAxisCell), toggleBg())

    stickBinding != null
      ? optionRow(loc("controls/analog/sensitivity", "Sensitivity"), sensitivitySlider(actionName, cellData.column), toggleBg())
      : null

    dainput.get_action_type(cellData.ah) != dainput.TYPE_STICK_DELTA
      ? optionRow(loc("controls/analog/deadzoneThres", "Deadzone"), axisSetupSlider(actionName, cellData.column, "deadZoneThres", {min=0, max=0.4,step=0.01, morphText=showDeadZone}), toggleBg())
      : null
    dainput.is_action_stateful(cellData.ah)
      ? optionRow(loc("controls/analog/relIncScale", "changeStep"), axisSetupSlider(actionName, cellData.column, "relIncScale", {min=0.1, max=10.0, step=0.1, morphText=showRelScale}), toggleBg())
      : null
    dainput.get_action_type(cellData.ah) != dainput.TYPE_STICK_DELTA
      ? optionRow(loc("controls/analog/nonlinearity"), axisSetupSlider(actionName, cellData.column, "nonLin", {min=0, max=4, step=0.5}), toggleBg())
      : null

    dainput.get_action_type(cellData.ah) != dainput.TYPE_STICK_DELTA && stickBinding != null
      ? optionRow(loc("controls/analog/axisSnapAngK", "Axis snap factor"), axisSetupSlider(actionName, cellData.column, "axisSnapAngK", {min=0, max=1, step=0.025, morphText=showDeadZone}), toggleBg())
      : null

    stickBinding
      ? optionRow(loc("controls/analog/isInvertedX", "Invert X"), invertCheckbox(actionName, cellData.column, 0), toggleBg())
      : null
    stickBinding
      ? optionRow(loc("controls/analog/isInvertedY", "Invert Y"), invertCheckbox(actionName, cellData.column, 1), toggleBg())
      : null
    axisBinding
      ? optionRow(loc("controls/analog/isInverted"), invertCheckbox(actionName, cellData.column, -1), toggleBg())
      : null
  )



  toggleBg = makeBgToggle()

  if (!actionTags.contains("_noDigitalButtons_")){
    rows.append(sectionHeader(loc("controls/digital-buttons-section", "Digital buttons")))

    if (axisBinding) {
      if (actionType == dainput.TYPE_STEERWHEEL || dainput.is_action_stateful(cellData.ah)) {
        local texts = null
        if (isValidDevice(axisBinding.minBtn.devId))
          texts = [format_ctrl_name(axisBinding.minBtn.devId, axisBinding.minBtn.btnId, true)]
        else
          texts = []
        let cell = bindingCell(cellData.ah, cellData.column, "minBtn", texts, null, selectedAxisCell)
        rows.append(optionRow(loc($"controls/{actionName}/min", loc("controls/min")), cell, toggleBg()))
      }

      local texts = null
      if (isValidDevice(axisBinding.maxBtn.devId))
        texts = [format_ctrl_name(axisBinding.maxBtn.devId, axisBinding.maxBtn.btnId, true)]
      else
        texts = []
      let cell = bindingCell(cellData.ah, cellData.column, "maxBtn", texts, null, selectedAxisCell)
      rows.append(optionRow(loc($"controls/{actionName}/max", loc("controls/max")), cell, toggleBg()))

      if (dainput.is_action_stateful(cellData.ah)){
        local textsAdd = isValidDevice(axisBinding.decBtn.devId)
          ? [format_ctrl_name(axisBinding.decBtn.devId, axisBinding.decBtn.btnId, true)]
          : []
        local cellAdd = bindingCell(cellData.ah, cellData.column, "decBtn", textsAdd, null, selectedAxisCell)
        rows.append(optionRow(loc($"controls/{actionName}/dec", loc("controls/dec")), cellAdd, toggleBg()))
        textsAdd = isValidDevice(axisBinding.incBtn.devId)
          ? [format_ctrl_name(axisBinding.incBtn.devId, axisBinding.incBtn.btnId, true)]
          : []
        cellAdd = bindingCell(cellData.ah, cellData.column, "incBtn", textsAdd, null, selectedAxisCell)
        rows.append(optionRow(loc($"controls/{actionName}/inc", loc("controls/inc")), cellAdd, toggleBg()))

      }
    }
    else if (stickBinding) {
      let directions = [
        {locSuffix="X/min", axisId="axisXId", dirBtn="minXBtn"}
        {locSuffix="X/max", axisId="axisXId", dirBtn="maxXBtn"}
        {locSuffix="Y/max", axisId="axisYId", dirBtn="maxYBtn"}
        {locSuffix="Y/min", axisId="axisYId", dirBtn="minYBtn"}
      ]
      foreach (dir in directions) {
        let btn = stickBinding[dir.dirBtn]
        let texts = isValidDevice(btn.devId) ? [format_ctrl_name(btn.devId, btn.btnId, true)] : []

        rows.append(optionRow(loc($"controls/{actionName}{dir.locSuffix}", loc($"controls/{dir.locSuffix}")),
          bindingCell(cellData.ah, cellData.column, dir.dirBtn, texts, null, selectedAxisCell), toggleBg()))
      }
    }
  }


  let children = [
    title

    makeVertScroll({
      flow = FLOW_VERTICAL
      key = "axis"
      size = FLEX_H
      padding = static [fsh(1), 0]
      clipChildren = true

      children = rows
    })

    buttons
  ]

  return {
    watch = actionRecording
    size = flex()
    behavior = Behaviors.Button
    stopMouse = true
    stopHotkeys = true
    skipDirPadNav = true
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    rendObj = ROBJ_WORLD_BLUR
    color = Color(190,190,190,255)

    function onClick() {
      configuredAxis.set(null)
    }

    children = {
      size = static [sw(80), sh(80)]
      rendObj = ROBJ_WORLD_BLUR
      color = Color(120,120,120,255)
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER

      stopMouse = true
      stopHotkeys = true

      children
    }
  }
}


function actionTypeSelect(_cell_data, watched, value) {
  let stateFlags = Watched(0)
  return function() {
    let selected = watched.get() == value
    let sf = stateFlags.get()
    let color = (sf & S_HOVER) ? BtnBdHover : BtnBdNormal
    return {
      behavior = Behaviors.Button
      onElemState = @(s) stateFlags.set(s)
      function onClick() {
        watched.set(value)
      }
      watch = [watched, stateFlags]
      flow = FLOW_HORIZONTAL
      valign = ALIGN_BOTTOM
      
      gap = hdpx(10)
      children = [
        {
          rendObj = ROBJ_TEXT
          text = fa["circle-o"]
          color
          font = fontawesome.font
          fontSize = hdpxi(23)
          valign = ALIGN_CENTER
          halign = ALIGN_CENTER
          children = selected ? { color, text = fa["circle"], rendObj = ROBJ_TEXT, font = fontawesome.font, fontSize = hdpxi(9) } : null
        }
        {
          rendObj = ROBJ_TEXT
          color = (sf & S_HOVER) ? BtnTextHover : BtnTextNormal
          text = loc(eventTypeLabels[value])
        }.__update(body_txt)
      ]
    }
  }
}

let selectEventTypeHdr = {
  size = FLEX_H
  rendObj = ROBJ_TEXT
  text = loc("controls/actionEventType", "Action on")
  color = TextNormal
  halign = ALIGN_RIGHT
}.__update(body_txt)

function buttonSetupWindow() {
  let cellData = configuredButton.get()
  let binding = dainput.get_digital_action_binding(cellData.ah, cellData.column)
  let eventTypeValue = Watched(binding.eventType)
  let modifierType = Watched(binding.unordCombo)
  let needShowModType = Watched(binding.modCnt > 0)
  modifierType.subscribe_with_nasty_disregard_of_frp_update(function(new_val) {
    binding.unordCombo = new_val
    haveChanges.set(true)
  })

  let currentBinding = {
    flow = FLOW_HORIZONTAL
    children = bindedComp(buildDigitalBindingText(binding))
  }
  eventTypeValue.subscribe_with_nasty_disregard_of_frp_update(function(new_val) {
    binding.eventType = new_val
    haveChanges.set(true)
  })

  let actionName = dainput.get_action_name(cellData.ah)
  let title = {
    rendObj = ROBJ_TEXT
    color = TextNormal
    text = loc($"controls/{actionName}", actionName)
    margin = fsh(3)
  }.__update(h2_txt)

  let stickyToggle = Watched(binding.stickyToggle)
  stickyToggle.subscribe_with_nasty_disregard_of_frp_update(function(new_val) {
    binding.stickyToggle = new_val
    haveChanges.set(true)
  })

  let buttons = {
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    halign = ALIGN_RIGHT
    children = [
      textButton(loc("mainmenu/btnOk", "OK"), function() {
        configuredButton.set(null)
      }, {
          hotkeys = [
            ["^{0} | J:Start | Esc".subst(JB.B), { description={skip=true} }],
          ]
      })
    ]
  }

  let isStickyToggle = {
    margin = static [fsh(1), 0, 0, fsh(0.4)]
    children = checkbox(stickyToggle,
      {
        color = TextNormal
        text = loc("controls/digital/mode/toggle")
      }.__update(body_txt)
    )
  }

  let eventTypesChildren = getAllowedBindingsTypes(cellData.ah)
    .map(@(eventType) actionTypeSelect(cellData, eventTypeValue, eventType))
    .append(isStickyToggle)

  let selectEventType = @() {
    flow = FLOW_VERTICAL
    size = FLEX_H
    watch = eventTypeValue
    children = eventTypesChildren
  }

  let triggerTypeArea = {
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    valign = ALIGN_TOP
    gap = fsh(2)
    children = [
      selectEventTypeHdr
      selectEventType
    ]
  }

  let selectModifierType = @() {
    watch = needShowModType
    hplace = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = needShowModType.get() ? [
      checkbox(modifierType, {text = loc("controls/unordCombo")})
    ] : null
  }
  let children = [
    title
    {
      halign = ALIGN_CENTER
      flow = FLOW_VERTICAL
      children = [currentBinding, selectModifierType]
    }
    {
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = triggerTypeArea
    }
    {size = flex(10) }
    buttons
  ]

  return {
    size = flex()
    behavior = Behaviors.Button
    skipDirPadNav = true
    stopMouse = true
    stopHotkeys = true
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    rendObj = ROBJ_WORLD_BLUR
    color = Color(190,190,190,255)

    function onClick() {
      configuredAxis.set(null)
    }

    children = {
      size = static [sw(80), sh(80)]
      rendObj = ROBJ_WORLD_BLUR
      color = Color(120,120,120,255)
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER
      gap = hdpx(70)

      children = children
    }
  }
}

let saSize = Computed(@() sw(100)-2*safeAreaHorPadding.get())

function controlsSetup() {
  let width = min(sw(90), saSize.get())
  let menu = {
    rendObj = ROBJ_WORLD_BLUR
    size = [width, sh(85)]
    fillColor = Color(0,0,0,180)
    transform = {}
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    flow = FLOW_VERTICAL
    gap = static hdpx(4)
    
    stopMouse = true
    children = [
      settingsHeaderTabs(currentTab, tabsList)
      {
        size = flex()
        flow = FLOW_VERTICAL
        gap = static hdpx(4)
        padding = static [hdpx(5),hdpx(10)]
        children = [
          searchInputBlock
          @() {
            watch = [customSettingsFilter, currentTab]
            size = flex()
            children = currentTab.get() == "Options" && customSettingsFilter.get().len() <= 0 ? options
              : bindingsPage(currentTab.get(), customSettingsFilter.get())
          }
        ]
      }
      mkWindowButtons(width)
    ]
  }

  let root = {
    key = "controls"
    size = static [sw(100), sh(100)]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    watch = [
      actionRecording, configuredAxis, configuredButton, currentTab, saSize,
      generation, controlsSettingOnlyForGamePad, haveChanges
    ]

    children = [
      static {
        size = static [sw(100), sh(100)]
        stopHotkeys = true
        stopMouse = true
        rendObj = ROBJ_WORLD_BLUR
        color = Color(130,130,130)
      }
      menu
      configuredAxis.get()!=null ? axisSetupWindow : null
      configuredButton.get()!=null ? buttonSetupWindow : null
      actionRecording.get()!=null ? recordingWindow : null
    ]

    transform = static {
      pivot = [0.5, 0.25]
    }
    animations = pageAnim
    sound = static {
      attach="ui_sounds/menu_enter"
      detach="ui_sounds/menu_exit"
    }
    onDetach = @() customSettingsFilter.set("")
    behavior = DngBhv.ActivateActionSet
    actionSet = "StopInput"
  }

  return root
}

generation.subscribe(@(_) eventbus_send(CONTROLS_SETUP_CHANGED_EVENT_ID, null))

return {
  controlsMenuUi = controlsSetup
  showControlsMenu
}
