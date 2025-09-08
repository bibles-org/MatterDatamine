from "%ui/ui_library.nut" import *

let {sub_txt} = require("%ui/fonts_style.nut")
let {lastActiveControlsType, isGamepad} = require("%ui/control/active_controls.nut")
let controllerType = require("%ui/control/controller_type.nut")
let controlsTypes = require("%ui/control/controls_types.nut")
let gamepadImgByKey = require("%ui/components/gamepadImgByKey.nut")
let navState = {v = []}
let getNavState = @(...) navState.v
let navStateGen = Watched(0)
let {BtnTextNormal} = require("%ui/components/colors.nut")
let JB = require("%ui/control/gui_buttons.nut")
let {safeAreaHorPadding, safeAreaVerPadding, safeAreaAmount} = require("%ui/options/safeArea.nut")
let {getHotkeysComps, hotkeysPanelCompsGen} = require("hotkeysPanelStateComps.nut")
let {cursorPresent, cursorOverStickScroll, config, cursorOverClickable} = gui_scene

let text_font = sub_txt?.font
let text_size = sub_txt.fontSize

let panel_ver_padding = fsh(1)

function mktext(text){
  return {
    rendObj = ROBJ_TEXT
    text
    color = BtnTextNormal
    font=text_font
    fontSize = text_size
  }
}

let defaultJoyAHint = loc("ui/cursor.activate")

function _filter(hotkey, devidsmap){
  let descrExist = "description" in hotkey
  return hotkey.devId in devidsmap && (!descrExist || hotkey.description != null)
}

let showKbdHotkeys = false
let gamepadids = {[DEVID_JOYSTICK]=true}
let kbdids = {[DEVID_KEYBOARD]=true, [DEVID_MOUSE]=true}
let filterFuncByGamepad = {
  [true] = @(hotkey) _filter(hotkey, gamepadids),
  [false] = @(hotkey) showKbdHotkeys && _filter(hotkey, kbdids)
}

gui_scene.setHotkeysNavHandler(function(state) {
  navState.v = state
  navStateGen.modify(@(v) v+1)
})

let padding = hdpx(5)
let height = text_size

function mkNavBtn(params = {hotkey=null, gamepad=true}){
  let description = params?.hotkey?.description
  let skip = description?.skip
  if (skip)
    return null
  let btnNames = params?.hotkey.btnName ?? []
  let children = params?.gamepad
       ? btnNames.map(@(btnName) gamepadImgByKey.mkImageCompByDargKey(btnName, {height=height}))
       : btnNames.map(@(btnName) {rendObj = ROBJ_TEXT text = btnName })

  if (type(description)=="string")
    children.append(mktext(description))

  return {
    size = [SIZE_TO_CONTENT, height]
    gap = fsh(0.5)
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    children = children
    padding = hdpx(5)
  }
}

function combine_func(a, b){
  return (a.action==b.action)
}

let isActivateKey = @(key) JB.A == key.btnName

function combine_hotkeys(data, filter_func){
  let hotkeys = []
  local isActivateForced = false
  foreach (k in data) {
    if (isActivateKey(k)) {
      isActivateForced = true
      continue
    }
    if (!filter_func(k))
      continue
    let t = clone k
    local key_used = false
    foreach (_i,r in hotkeys) {
      if (combine_func(r,t)) {
        r.btnName.append(t.btnName)
        key_used = true
        break
      }
    }
    if (!key_used) {
      t.btnName = [t.btnName]
      hotkeys.append(t)
    }
  }
  return { hotkeys, needShowHotkeys = isActivateForced || hotkeys.len() > 0 }
}

function getJoyAHintText(data, filter_func) {
  local hotkeyAText = defaultJoyAHint
  foreach (k in data)
    if (filter_func(k) && isActivateKey(k)) {
      if (typeof k?.description == "string")
        hotkeyAText = k.description
      else if (k?.description?.skip)
        hotkeyAText = null
    }
  return hotkeyAText
}


let joyAHint = Computed(function() {
  return getJoyAHintText(navState.v, filterFuncByGamepad[isGamepad.get()])
})

function svgImg(image){
  let h = gamepadImgByKey.getBtnImageHeight(image, height)
  return {
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    rendObj = ROBJ_IMAGE
    image = Picture("!ui/skin#{0}.svg:{1}:{1}:K".subst(image, h.tointeger()))
    keepAspect = true
    size = [h, h]
  }
}
function manualHint(images, text=""){
  return {
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    gap = fsh(0.5)
    children = images.map(@(image) svgImg(image)).append(mktext(text))
    padding = padding
  }
}

function gamepadcursornav_images(cType){
  if (cType == controlsTypes.ds4gamepad)
    return ["ds4/lstick_4" "ds4/dpad"]
  if (cType == controlsTypes.nxJoycon)
    return ["nswitch/lstick_4" "nswitch/dpad"]
  return ["x1/lstick_4" "x1/dpad"]
}

function gamepadcursorclick_image(imagesMap) {
  let clickButtons = config.getClickButtons()
  return clickButtons
    .filter(@(btn) btn.startswith("J:"))
    .map(@(btn) imagesMap?[btn])
}

function gamepadCursor() {
  let clickHint = manualHint(gamepadcursorclick_image(gamepadImgByKey.keysImagesMap.value), joyAHint.get())
  let clickHintStub = {size = [calc_comp_size(clickHint)[0], 0], key = {}}
  let scrollHint = manualHint([gamepadImgByKey.keysImagesMap.value?["J:R.Thumb.hv"]], loc("ui/cursor.scroll"))
  return {
    flow = FLOW_HORIZONTAL
    hplace = ALIGN_LEFT
    gap = fsh(2.5)
    size = [SIZE_TO_CONTENT, height]
    valign = ALIGN_CENTER
    zOrder = Layers.MsgBox
    watch = [joyAHint, lastActiveControlsType, cursorOverStickScroll, cursorOverClickable,gamepadImgByKey.keysImagesMap]
    children = [
      manualHint(gamepadcursornav_images(controllerType.value),loc("ui/cursor.navigation"))
      cursorOverClickable.value && joyAHint.value ? clickHint : clickHintStub
      cursorOverStickScroll.value ? scrollHint : null
      {size = [fsh(6),0]}
    ]
  }
}

let show_tips = Computed(@() cursorPresent.get() && isGamepad.get() && combine_hotkeys(getNavState(navStateGen.get()), filterFuncByGamepad[isGamepad.get()]).needShowHotkeys)

function tipsC(){
  let filtered_hotkeys = combine_hotkeys(getNavState(), filterFuncByGamepad[isGamepad.get()]).hotkeys
  let tips = (cursorPresent.get() && isGamepad.get()) ? [ gamepadCursor] : []
  tips.extend(filtered_hotkeys.map(@(hotkey) mkNavBtn({hotkey, gamepad=isGamepad.get()})))
  tips.extend(getHotkeysComps().values())
  return {
    gap = fsh(2.5)
    size = SIZE_TO_CONTENT
    flow = FLOW_HORIZONTAL
    watch = [isGamepad, cursorPresent, navStateGen, hotkeysPanelCompsGen]
    zOrder = Layers.MsgBox
    children = tips
  }
}

let hotkeysBarHeight = Computed(@() height + panel_ver_padding + max(panel_ver_padding, safeAreaVerPadding.get()))

let hotkeysButtonsBarStyle = @() {
  rendObj = null
  fillColor = null
  size = [SIZE_TO_CONTENT, hotkeysBarHeight.get()]
}
function hotkeysButtonsBar() {
  return show_tips.get() ? {
    vplace = ALIGN_BOTTOM
    padding = [panel_ver_padding,fsh(4),panel_ver_padding,max(fsh(5), safeAreaHorPadding.get())]
    watch = [show_tips, safeAreaAmount]
    children = tipsC
  }.__merge(hotkeysButtonsBarStyle()) : {watch = show_tips}
}

return {hotkeysButtonsBar, hotkeysBarHeight}