import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let inspectingAmmoCountAffectEid = Watched(ecs.INVALID_ENTITY_ID)

ecs.register_es("ammo_count_knowledge_ui_es", {
  [["onInit", "onChange"]] = function(_, comp) {
    inspectingAmmoCountAffectEid.set(comp.ammo_count_knowledge_controller__inspectingAffectEid)
  },
  onDestroy = function(_, _comp) {
    inspectingAmmoCountAffectEid.set(ecs.INVALID_ENTITY_ID)
  }
},
{
  comps_rq = [["watchedByPlr"]],
  comps_track = [["ammo_count_knowledge_controller__inspectingAffectEid", ecs.TYPE_EID]]
})

return {
  inspectingAmmoCountAffectEid
}