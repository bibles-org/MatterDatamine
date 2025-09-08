from "%ui/ui_library.nut" import *

let { h2_txt } = require("%ui/fonts_style.nut")
let defTransform = {}
let objectivePointsBhv = [DngBhv.DistToPriority, Behaviors.OverlayTransparency]
let { tipCmp } = require("%ui/hud/tips/tipComponent.nut")

let defaultColor = Color(220, 220, 220, 220)
let pinggedColor = Color(255, 225, 50, 220)

function objectiveMarker(eid, children, data_params = {}, style={}) {
  return {
    data = {
      eid = eid
      maxDistance = 10000

      clampToBorder = true
    }.__update(data_params)

    key = $"objective_{eid}"

    transform = defTransform
    sortOrder = eid
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    children = children
  }.__update(style)
}

let icon = @(iconName, params = {}) {
  rendObj = ROBJ_IMAGE
  size = [sh(3), sh(3)]
  color = params?.color ?? Color(220,220,220,220)
  image = Picture($"!ui/skin#{iconName}")
  behavior = objectivePointsBhv
  transform = defTransform
}.__update(params)


function objective_short(eid, marker) {
  let {iconName} = marker
  if (iconName=="")
    return null
  return objectiveMarker(eid, icon(iconName, {data = {eid=eid}}), {yOffs=1, maxDistance = 10000, distScaleFactor = 0.3})
}

function visible_interactable_ctor(eid, marker) {
  let children = {
    children = [
      icon(marker.icon).__update({size = [sh(10), sh(10)], color=marker.pingged ? pinggedColor : defaultColor}),
      {
        rendObj = ROBJ_TEXT
        text = loc(marker.name)
        markerFlags = DngBhv.MARKER_SHOW_ONLY_IN_VIEWPORT
        pos = [sh(11), sh(3)]
        data = {eid = eid }
        behavior = objectivePointsBhv
      }.__update(h2_txt)
    ]
  }
  let data_params = {yOffs = marker?.yOffs ?? 0.4, distScaleFactor = marker.pingged ? 0.5 : 1, clampToBorder=marker.pingged}
  return objectiveMarker(eid, children, data_params)
}

function game_trigger_marker_ctors(eid, marker) {
  let tip = tipCmp({
    inputId = marker.inputId
    text = loc(marker.text)
  })
  return tip.__merge({
    data = {
      eid
      minDistance = marker.minDistance
      maxDistance = marker.maxDistance
      clampToBorder = marker.clampToBorder
      worldPos = marker.pos
    }
  })
}

return {
  visible_interactable_ctor
  objective_small_ctor = objective_short
  game_trigger_marker_ctors
}
