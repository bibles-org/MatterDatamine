from "%ui/ui_library.nut" import *

#allow-auto-freeze

let defTransform = {}

let point = freeze({
  transform = defTransform
  children = {
    rendObj = ROBJ_IMAGE
    opacity = 0.5
    size = fsh(40)
    picSaturate = 0.0
    image = Picture("ui/aura_vision_arrow_a.avif")
  }
})

let arrow = freeze({
  transform = defTransform
  markerFlags = DngBhv.MARKER_ARROW
  children = {
    rendObj = ROBJ_IMAGE
    opacity = 1
    size = fsh(40)
    picSaturate = 0.0
    image = Picture("ui/aura_vision_arrow_a.avif")
  }
})

function hunter_minion_markers_ctor(eid, _){
  let data = {
    eid
    minDistance = 0.4
    maxDistance = 1300
    distScaleFactor = 0.6
    clampToBorder = false
    yOffs = 0.5
  }
  return @(){
    data
    transform = defTransform
    children = point
    sortOrder = eid
  }
}

function hunter_minion_arrow_markers_ctor(eid, _){
  let data = {
    eid
    minDistance = 0.4
    maxDistance = 1300
    clampToBorder = true
    yOffs = 0.5
  }
  return @(){
    data
    transform = defTransform
    children = arrow
    sortOrder = eid
  }
}


return {
  hunter_minion_markers_ctor
  hunter_minion_arrow_markers_ctor
}