import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { localPlayerEid } = require("%ui/hud/state/local_player.nut")
let { CmdCreateMapPoint } = require("dasevents")
let { Point2 } = require("dagor.math")

function command(event, minimapState){
  let rect = event.targetRect
  let elemW = rect.r - rect.l
  let elemH = rect.b - rect.t
  let relX = (event.screenX - rect.l - elemW * 0.5)
  let relY = (event.screenY - rect.t - elemH * 0.5)
  let worldPos = minimapState.mapToWorld(Point2(relX, relY))
  ecs.g_entity_mgr.sendEvent(localPlayerEid.value, CmdCreateMapPoint({x = worldPos.x, z = worldPos.z}))
}

return command