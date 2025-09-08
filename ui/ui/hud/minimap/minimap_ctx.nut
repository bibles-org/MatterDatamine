import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
from "minimap" import MinimapContext

let { Point2 } = require("dagor.math")

let mmapComps = {comps_ro = [
  ["left_top", ecs.TYPE_POINT2],
  ["right_bottom", ecs.TYPE_POINT2],
  ["farLeftTop", ecs.TYPE_POINT2, Point2(-100,-100)],
  ["farRightBottom", ecs.TYPE_POINT2, Point2(100,100)],
  ["northAngle", ecs.TYPE_FLOAT, 0.0],
  ["mapTex", ecs.TYPE_STRING],
  ["farMapTex", ecs.TYPE_STRING, null]
]}

let config = {
  mapColor = Color(255, 255, 255, 255)
  fovColor = Color(10, 0, 0, 200)
  mapTex = ""
  left_top = Point2(-100,-100)
  right_bottom = Point2(100,100)
  northAngle = 0.0
}


let mmContext = persist("ctx", function() {
  let ctx = MinimapContext()
  ctx.setup(config)
  return ctx
})

let mmContextData = Watched(config)

function onMinimap(_eid, comp){
  let right_bottom = comp["right_bottom"]
  let left_top = comp["left_top"]
  let width = right_bottom.x - left_top.x
  let height = right_bottom.y - left_top.y
  let mult = 0.25

  let conf = config.__merge({
    mapTex = comp["mapTex"]
    right_bottom
    left_top
    back_right_bottom = Point2(right_bottom.x + mult * width, right_bottom.y + mult * height)
    back_left_top = Point2(left_top.x - mult * width, left_top.y - mult * height)
    northAngle = comp["northAngle"]
  })
  mmContextData.set(conf)
  mmContext.setup(conf)
}

function resetToDefaults(...){
  mmContextData.set(config)
  mmContext.setup(config)
}

ecs.register_es("minimap_ui_es", { onInit = onMinimap, onDestroy = resetToDefaults }, mmapComps)


return {
  mmContext
  mmContextData
}

