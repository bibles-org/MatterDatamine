from "%ui/ui_library.nut" import *
from "%ui/components/colors.nut" import BtnBdNormal, BtnBdActive, BtnBdHover, BtnBgNormal, BtnBgHover
let {setTooltip} = require("%ui/components/cursors.nut")
let {fontawesome} = require("%ui/fonts_style.nut")
let {stateChangeSounds} = require("%ui/components/sounds.nut")
let fa = require("%ui/components/fontawesome.map.nut")
let {sound_play} = require("%dngscripts/sound_system.nut")
let {isGamepad} = require("%ui/control/active_controls.nut")

let calcColor = @(sf)
  (sf & S_ACTIVE) ? BtnBdActive
  : (sf & S_HOVER) ? BtnBdHover
  : BtnBdNormal

let boxHeight = hdpx(25)
let mkCheckMark = @(stateFlags, state, group) @(){
  watch = [stateFlags, state]
  validateStaticText = false
  text = state.get() ? fa["check"] : null
  vplace = ALIGN_CENTER
  color = calcColor(stateFlags.get())
  size = [boxHeight,SIZE_TO_CONTENT]
  group
  rendObj = ROBJ_INSCRIPTION
  halign = ALIGN_CENTER
}.__update(fontawesome, {fontSize = hdpx(12)})

let mkSwitchKnob = @(stateFlags, state, group) @(){
  size = [boxHeight-hdpx(2),boxHeight-hdpx(2)] rendObj = ROBJ_BOX, borderRadius = hdpx(1),
  borderWidth = hdpx(1),
  fillColor = calcColor(stateFlags.get())
  borderColor = Color(0,0,0,30)
  hplace = state.get() ? ALIGN_RIGHT : ALIGN_LEFT
  vplace = ALIGN_CENTER
  watch = [stateFlags, state]
  margin = hdpx(1)
  group
}

function switchbox(stateFlags, state, group) {
  let checkMark = mkCheckMark(stateFlags, state, group)
  let switchKnob = mkSwitchKnob(stateFlags, state, group)
  return function() {
    let sf = stateFlags.get()
    return {
      rendObj = ROBJ_BOX
      fillColor = sf & S_HOVER ? BtnBgHover : BtnBgNormal
      borderWidth = hdpx(1)
      borderColor = calcColor(sf)
      borderRadius = hdpx(1)
      watch = stateFlags
      size = [boxHeight*2+hdpx(2), boxHeight]
      children = [checkMark, switchKnob]
    }
  }
}

function label(stateFlags, params, group, onClick, isInteractive) {
  if (type(params) != type({})){
    params = { text = params }
  }
  return @() {
    rendObj = ROBJ_TEXT
    margin = [fsh(1), 0, fsh(1), 0]
    color = calcColor(stateFlags.get())
    watch = stateFlags
    group
    behavior = isInteractive ? [Behaviors.Marquee, Behaviors.Button] : null
    onClick
    speed = [hdpx(40),hdpx(40)]
    delay =0.3
    scrollOnHover = true
  }.__update(params ?? {})
}

let hotkeyLoc = loc("controls/check/toggleOrEnable/prefix", "Toggle")













return function (state, label_text_params=null, params = {}) {
  let { group = ElemGroup(), setValue = @(v) state(v), tooltip = null, isInteractive  = true } = params
  let stateFlags = Watched(0)
  let onHover = tooltip ? @(on) setTooltip(on ? tooltip : null) : null
  function onClick(){
    setValue(!state.get())
    sound_play(state.get() ? "ui_sounds/flag_set" : "ui_sounds/flag_unset")
  }
  let hotkeysElem = params?.useHotkeys ? {
    key = "hotkeys"
    hotkeys = [
      ["Left | J:D.Left", hotkeyLoc, onClick],
      ["Right | J:D.Right", hotkeyLoc, onClick],
    ]
  } : null
  return function(){
    let children = [
      switchbox(stateFlags, state, group),
      label(stateFlags, label_text_params, group, onClick, isInteractive),
      (stateFlags.get() & S_HOVER) ? hotkeysElem : null
    ]
    if (params?.textOnTheLeft)
      children.reverse()
    return {
      flow = FLOW_HORIZONTAL
      valign = ALIGN_CENTER
      gap = fsh(1)
      key = state
      group
      watch = [state, stateFlags, isGamepad]
      behavior = isInteractive ? Behaviors.Button : null
      size = SIZE_TO_CONTENT
      onElemState = @(sf) stateFlags.set(sf)
      onClick
      onHover
      sound = stateChangeSounds
      xmbNode = params?.xmbNode
      children
    }.__update(params?.override ?? {})
  }
}
