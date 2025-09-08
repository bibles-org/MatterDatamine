import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
let {EventHeroChanged} = require("gameevents")

let {get_controlled_hero} = require("%dngscripts/common_queries.nut")








let controlledHeroEid = Watched(ecs.INVALID_ENTITY_ID)

wlog(controlledHeroEid, "controlled: ")

ecs.register_es("controlled_hero_eid_init_es", {
  [["onInit", "onChange"]] = function(_eid,comp){
    if (comp.is_local)
      controlledHeroEid.update(get_controlled_hero())
  }
  onDestroy = function(_eid,comp){
    if (comp.is_local)
      controlledHeroEid.update(ecs.INVALID_ENTITY_ID)
  }
}, {comps_track=[["possessed", ecs.TYPE_EID], ["is_local", ecs.TYPE_BOOL]], comps_rq=["player"]})


ecs.register_es("controlled_hero_eid_es", {
  [EventHeroChanged] = function(evt, _eid,_comp){
    let e = evt[0]
    log($"controlledHeroEid = {e}")
    controlledHeroEid.update(e)
  }
}, {})

return{
  controlledHeroEid
}