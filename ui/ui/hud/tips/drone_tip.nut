from "%ui/ui_library.nut" import *

let {sub_txt, giant_txt} = require("%ui/fonts_style.nut")
let {tipCmp} = require("%ui/hud/tips/tipComponent.nut")
let {isDroneMode, droneConnectionQuality, droneShowConnectionWarning} = require("%ui/hud/state/drone_state.nut")
let {mkTextArea} = require("%ui/components/commonComponents.nut")
let {isSpectator} = require("%ui/hud/state/spectator_state.nut")
let {RedWarningColor} = require("%ui/components/colors.nut")

let DRONE_TIPS = ["Helicopter.Fly", "Helicopter.Nose", "Helicopter.Roll", "Drone.DropGrenade", "Drone.Leave"]
let DRONE_LOCALS = ["Helicopter.Fly", "Helicopter.Nose", "Helicopter.Roll", "Drone.DropGrenade", "Drone.Leave"]

let function prepareTipCmp(key, localeKey) {
  return tipCmp({
      inputId = key
      text = loc($"controls/{localeKey}")
      style = {rendObj = null}
    }.__update(sub_txt))
}

let function prepareConnectionQuality(idx) {
  let height = 40 * idx
  let colors = [Color(255,112,112,200), Color(255,255,112,200), Color(112,255,112,200)]
  let color = (idx <= droneConnectionQuality.value) ? colors[max(0, droneConnectionQuality.value - 1)] : Color(77,77,77,200)
  return {
    rendObj = ROBJ_BOX
    fillColor = color
    size = [hdpx(40), hdpx(height)]
  }
}

let function connectionQuality() {
  let res = { watch = isDroneMode }
  if (!isDroneMode.value)
    return res
  return {
    watch = [isDroneMode, droneConnectionQuality]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_BOTTOM
    gap = hdpx(3)
    children = [
      prepareConnectionQuality(1),
      prepareConnectionQuality(2),
      prepareConnectionQuality(3)
    ]
  }
}

let function droneTip() {
  let res = { watch = [isDroneMode, isSpectator] }
  if (!isDroneMode.value || isSpectator.value)
    return res
  return {
    watch = [isDroneMode, isSpectator]
    flow = FLOW_VERTICAL
    gap = hdpx(5)
    children = DRONE_TIPS.map(@(key, idx) prepareTipCmp(key, DRONE_LOCALS[idx]))
    rendObj = ROBJ_WORLD_BLUR
  }
}

function droneWeakSignalTip() {
  let watch = [isDroneMode, droneShowConnectionWarning]
  if (!isDroneMode.value || !droneShowConnectionWarning.value)
    return { watch }
  return {
    watch
    rendObj = ROBJ_BOX
    size = flex()
    children = mkTextArea(loc("hud/drone_weak_signal"), {
      halign = ALIGN_CENTER
      vplace = ALIGN_CENTER
      color = RedWarningColor
    }.__update(giant_txt))
  }
}

return {
  droneTip,
  connectionQuality
  droneWeakSignalTip
}