import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {get_controlled_hero} = require("%dngscripts/common_queries.nut")
let {get_sync_time} = require("net")

let isExtracting = Watched(false)
let alreadyExtracted = Watched(false)
let timeEnd = Watched(-1.0)
let closestExtraction = Watched(ecs.INVALID_ENTITY_ID)

let extractionQuery = ecs.SqQuery("extractionQuery", {
  comps_ro = [
    ["extraction_enable_time__at", ecs.TYPE_FLOAT, -1.0]
  ]
})

ecs.register_es("extraction_preparing_state_es", {
  onInit = function(_eid, comp){
    let hero = get_controlled_hero()
    if (hero == comp.game_effect__attachedTo){
      timeEnd.set(comp.extraction_preparing_affect__extractAt)
      isExtracting.set(true)
      alreadyExtracted.set(false)
    }
  }
  onDestroy = function(_evt, _eid, comp){
    let hero = get_controlled_hero()
    if (hero == comp.game_effect__attachedTo){
      isExtracting.set(false)
      alreadyExtracted.set(timeEnd.value <= get_sync_time())
      timeEnd.set(-1.0)
    }
  }
},
{
  comps_ro = [
    ["extraction_preparing_affect__extractAt", ecs.TYPE_FLOAT],
    ["game_effect__attachedTo", ecs.TYPE_EID],
  ],
})

let extractionEnableTime = Computed(function(){
  local enableTime = -1.0
  extractionQuery.perform(closestExtraction.get(), function(_eid, comp){
    enableTime = comp.extraction_enable_time__at
  })
  return enableTime
})

ecs.register_es("extraction_missing_am_ui_es", {
  onChange = function(_eid, comp){
    closestExtraction.set(comp.hero_extraction__closestExtractionPortal)
    alreadyExtracted.set(false)
  }
  onDestroy = function(_eid, _comp){
    closestExtraction.set(ecs.INVALID_ENTITY_ID)
    alreadyExtracted.set(false)
  }
},
{
  comps_rq = [["hero", ecs.TYPE_TAG]],
  comps_track = [["hero_extraction__closestExtractionPortal", ecs.TYPE_EID]],
})

return {
  isExtracting,
  alreadyExtracted,
  timeEnd,
  closestExtraction,
  extractionEnableTime
}