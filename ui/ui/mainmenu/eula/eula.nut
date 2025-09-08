from "%ui/ui_library.nut" import *
import "%ui/components/colors.nut" as colors

let { h2_txt, body_txt } = require("%ui/fonts_style.nut")
let eulaLog = require("%sqstd/log.nut")().with_prefix("[EULA] ")
let platform = require("%dngscripts/platform.nut")
let {msgboxDefStyle, showMsgbox} = require("%ui/components/msgbox.nut")
let {makeVertScrollExt} = require("%ui/components/scrollbar.nut")
let {safeAreaHorPadding, safeAreaVerPadding} = require("%ui/options/safeArea.nut")
let {read_text_from_file, file_exists} = require("dagor.fs")
let {loadJson} = require("%sqstd/json.nut")
let {language} = require("%ui/state/clientState.nut")
let JB = require("%ui/control/gui_buttons.nut")
let {hotkeysBarHeight} = require("%ui/hotkeysPanel.nut")
let { nestWatched } = require("%dngscripts/globalState.nut")
let {processHypenationsCN = @(v) v, processHypenationsJP = @(v) v} = require("dagor.localize")

const NO_VERSION = -1

let json_load = @(file) loadJson(file, {logger = eulaLog, load_text_file = read_text_from_file})

function loadConfig(fileName) {
  let config = file_exists(fileName) ? json_load(fileName) : null
  local curLang = language.value.tolower()
  if (!(curLang in config))
    curLang = "english"
  return {
    version = config?[curLang]?.version ?? NO_VERSION
    filePath = config?[curLang]?.file
  }
}

let eula = loadConfig("%ui/mainMenu/eula/eula.json")

eulaLog("language:", language.get())
eulaLog("eula config:", eula)

let postProcessEulaText = platform.is_sony
  ? function() {
    let {getRegion, region} = require("sony")
    return function(text) {
      local eulaTxt = text
      let lang = language.get().tolower()
      if (lang.contains("chinese"))
        eulaTxt = processHypenationsCN(eulaTxt)
      else if (lang.contains("japanese"))
        eulaTxt = processHypenationsJP(eulaTxt)
      let regionKey = getRegion() == region.SCEA ? "scea" : "scee"
      let regionText = loc($"sony/{regionKey}")
      return $"{eulaTxt}{regionText}"
    }
  }()
  : function(text) {
      local eulaTxt = text
      let lang = language.get().tolower()
      if (lang.contains("chinese"))
        eulaTxt = processHypenationsCN(eulaTxt)
      else if (lang.contains("japanese"))
        eulaTxt = processHypenationsJP(eulaTxt)
      return eulaTxt
    }

let customStyleA = {hotkeys=[[$"^J:X | Enter | Space", {description={skip=true}}]]}
let customStyleB = {hotkeys=[[$"^Esc | {JB.B}", {description={skip=true}}]]}
let customStyleOK = {hotkeys=[[$"^Esc | {0} | Enter | Space | {JB.B} | {JB.A} | J:X", {description={skip=true}}]]}
let customStyleNoChoice = {hotkeys=[[$"^Esc | {0} | Enter | Space | J:X", {description={skip=true}}]]}

const FORCE_EULA = "FORCE_EULA"
let eulaStyle = (clone msgboxDefStyle)
eulaStyle.size <- [sw(80), sh(80)]
let forcedMsgBoxStyle = (clone eulaStyle)
forcedMsgBoxStyle.rawdelete("closeKeys")

function show(version, filePath, decisionCb=null, isUpdated=false) {
  if (version == NO_VERSION || filePath == null) {
    
    if (decisionCb)
      decisionCb?(true)
    return
  }
  local eulaTxt = read_text_from_file(filePath)
  eulaTxt = postProcessEulaText("\x09".join(eulaTxt.split("\xE2\x80\x8B")))
  let isForced = FORCE_EULA==isUpdated
  
  let eulaUiContent = @() {
    watch = [safeAreaHorPadding]
    size = [sw(80), sh(80)]
    gap = hdpx(20)
    flow = FLOW_VERTICAL
    padding = [safeAreaVerPadding.get(), safeAreaHorPadding.get(), safeAreaVerPadding.get()+hotkeysBarHeight.get(), safeAreaHorPadding.get()]
    children = [
      {rendObj = ROBJ_TEXT text = loc("Legals") hplace = ALIGN_CENTER}.__update(h2_txt)
      makeVertScrollExt({
        size = [flex(), SIZE_TO_CONTENT]
        halign = ALIGN_LEFT
        padding = [0, hdpx(20)]
        rendObj = ROBJ_SOLID
        color = Color(0,0,0)
        children = {
          size = [flex(), SIZE_TO_CONTENT]
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          color = colors.BtnTextNormal
          text = eulaTxt.replace("\t","  ")
          preformatted = FMT_KEEP_SPACES
        }.__update(sh(100) <= 720 ? h2_txt : body_txt)
      }, {
        size = flex()
        wheelStep = 30
      })
    ]
  }

  let eulaUi = {
    children = eulaUiContent
  }
  if (isUpdated || decisionCb==null) {
    eulaUi.buttons <- [
      {
        text = isForced ? loc("eula/accept") : loc("Ok")
        isCurrent = true
        action = @() decisionCb?(true)
        customStyle = isForced ? customStyleNoChoice : customStyleOK
      }
    ]
  }
  else {
    eulaUi.buttons <- [
      {
        text = loc("eula/accept")
        isCurrent = true
        action = @() decisionCb(true)
        customStyle = customStyleA
      },
      {
        text = loc("eula/reject")
        isCancel = true
        action = @() decisionCb(false)
        customStyle = customStyleB
      }
    ]
  }
  showMsgbox(eulaUi, isForced ? forcedMsgBoxStyle : eulaStyle)
}

let showEula = @(cb, isUpdated=false) show(eula.version, eula.filePath, cb, isUpdated)

console_register_command(@() showEula(@(a) log_for_user($"Result: {a}"), true), "eula.showUpdated")
console_register_command(@() showEula(@(a) log_for_user($"Result: {a}"), false), "eula.showNewUser")
console_register_command(@() showEula(null), "eula.showManualOpen")

let acceptedEulaVersionBeforeLogin = nestWatched("acceptedEulaBeforeLogin", null)

return {
  showEula = showEula
  eulaVersion = eula.version
  acceptedEulaVersionBeforeLogin
  FORCE_EULA
}
