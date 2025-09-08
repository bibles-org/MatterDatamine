from "%ui/ui_library.nut" import *

let defTransform = {}

let outImage = freeze({
  transform = defTransform
  markerFlags = DngBhv.MARKER_SHOW_ONLY_WHEN_CLAMPED | DngBhv.MARKER_ARROW
  children = {
    rendObj = ROBJ_IMAGE
    opacity = 0.7
    size = [fsh(80), fsh(80)]
    image = Picture("ui/aura_vision_arrow_a.avif")
  }
})

let inImage = freeze({
  transform = defTransform
  markerFlags = DngBhv.MARKER_SHOW_ONLY_IN_VIEWPORT
  children = {
    rendObj = ROBJ_IMAGE
    size = [fsh(70), fsh(70)]
    opacity = 0.5
    image = Picture("ui/aura_vision_arrow_a.avif")
  }
})

function hunter_vision_target_marker_arrow_ctors(eid, _){
  let data = {
    eid
    minDistance = 10.0
    maxDistance = 1300
    distScaleFactor = 0.9
    clampToBorder = true
  }
  return @(){
    data
    transform = defTransform
    children = outImage
  }
}

function hunter_vision_target_marker_main_ctors(eid, _){
  let data = {
    eid
    minDistance = 10.0
    maxDistance = 1300
    distScaleFactor = 0.95
  }
  return @(){
    data
    transform = defTransform
    children = inImage
  }
}

return {
  hunter_vision_target_marker_arrow_ctors
  hunter_vision_target_marker_main_ctors
}