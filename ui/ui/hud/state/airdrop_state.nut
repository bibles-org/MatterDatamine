from "dagor.math" import Point3
from "dagor.random" import rnd_float
from "net" import get_sync_time

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs


let airdropPredictedPositions = Watched({})
let sizeAirdropCirclesOnMap = Watched(30.0)

ecs.register_es("airdrop_create_circle", {
  onInit = function(_evt, eid, comp) {
    let rndOffset = Point3(rnd_float(-0.7, 0.7) * sizeAirdropCirclesOnMap.get(), 0.0, rnd_float(-0.7, 0.7) * sizeAirdropCirclesOnMap.get())
    let posForCircleAirdrop = rndOffset + comp.airdrop__moveTo
    airdropPredictedPositions.mutate(@(airdrop) airdrop[eid] <- {
      center = posForCircleAirdrop
      radius = sizeAirdropCirclesOnMap.get()
      color = Color(176, 234, 252)
      icon = comp.airdrop__icon
    })
  }
  onUpdate = function(_evt, eid, comp) {
    let currTime = get_sync_time()
    if (comp.airdrop__smokeOnGroundDestoyAt > -1.0 && currTime > comp.airdrop__smokeOnGroundDestoyAt)
      airdropPredictedPositions.mutate(function(airdropCircle) { airdropCircle.$rawdelete(eid) })
  }
  onDestroy = @(eid, _comp) airdropPredictedPositions.mutate(function(airdropCircle) { airdropCircle.$rawdelete(eid) })
}, {
    comps_rq = ["airdrop__createdByManager"]
    comps_ro = [
      [ "airdrop__moveTo", ecs.TYPE_POINT3 ],
      [ "airdrop__icon", ecs.TYPE_STRING ],
      [ "airdrop__smokeOnGroundDestoyAt", ecs.TYPE_FLOAT ],
    ]
}, {tags = "gameClient", updateInterval = 0.5, after="*", before="*" })


ecs.register_es("airdrop_get_radius_on_map", {
  [["onInit"]] = function(_evt, _eid, comp) {
    sizeAirdropCirclesOnMap.set(comp.airdrop_manager__radiusOnMapUi)
  }
}, {
  comps_ro = [
    [ "airdrop_manager__radiusOnMapUi", ecs.TYPE_FLOAT ]
  ]
}, {tags = "gameClient" })


return {
  airdropPredictedPositions
  sizeAirdropCirclesOnMap
}