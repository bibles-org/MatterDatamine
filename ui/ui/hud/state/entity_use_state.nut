from "%sqstd/math.nut" import lerp

from "dasevents" import NotifyItemHolderLoadingStart

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *



let customLongUseHintQuery = ecs.SqQuery("customLongUseHintQuery", {comps_ro = [["item__setCustomLongUseHint", ecs.TYPE_STRING]]})

let entityToUse = Watched(ecs.INVALID_ENTITY_ID)
let entityToUseOverrideLongUseHint = Watched(null)
let entityToUseTemplate = Watched(null)
let entityUseStart = Watched(-1)
let entityUseEnd = Watched(-1)

ecs.register_es("entityUsage",{
  [["onInit","onChange", NotifyItemHolderLoadingStart]] = function(_eid,comp){
    entityUseStart.set(comp["human_inventory__entityUseStart"])
    entityUseEnd.set(comp["human_inventory__progressBarEnd"])

    let eid = comp["human_inventory__entityToUse"]
    entityToUse.set(eid)
    entityToUseTemplate.set(ecs.g_entity_mgr.getEntityTemplateName(eid))
    local longUseHintOverride = null
    customLongUseHintQuery.perform(eid, function(_eid, querycomp) {
      longUseHintOverride = loc(querycomp.item__setCustomLongUseHint)
    })
    entityToUseOverrideLongUseHint.set(longUseHintOverride)
  },
  onDestroy = function(_eid,_comp) {
    entityUseEnd.set(-1.0)
    entityUseStart.set(-1.0)
    entityToUse.set(ecs.INVALID_ENTITY_ID)
    entityToUseTemplate.set(null)
    entityToUseOverrideLongUseHint.set(null)
  }
}, {comps_track=[
    ["human_inventory__entityUseStart",ecs.TYPE_FLOAT],
    ["human_inventory__progressBarEnd",ecs.TYPE_FLOAT],
    ["human_inventory__entityToUse",ecs.TYPE_EID]
  ], comps_rq=["watchedByPlr"]})

function calcItemUseProgress(time){
  if (time > entityUseEnd.get() || entityUseStart.get() < 0)
    return 0

  return lerp(entityUseStart.get(), entityUseEnd.get(), 0.0, 100.0, time)
}

return {
  medkitStartTime = entityUseStart
  medkitEndTime = entityUseEnd
  entityToUse
  entityUseEnd
  entityUseStart
  entityToUseTemplate
  entityToUseOverrideLongUseHint
  calcItemUseProgress
}
