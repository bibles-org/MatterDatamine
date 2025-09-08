import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let grenadesEids = Watched({})
let totalGrenades = Watched(0)

ecs.register_es("inventory_grenades_ui_es",
  {
    [["onInit", "onChange"]] = function(_, eid, comp) {
      let gType = comp.item__grenadeType
      let glType = comp.item__grenadeLikeType
      if (gType == "shell" && glType == null)
        return
      let grenadeType = gType ?? glType
      if (comp["item__containerOwnerEid"] == comp["item__humanOwnerEid"]) {
        grenadesEids.mutate(@(v) v[eid] <- grenadeType)
        totalGrenades.modify(@(v) v+1)
      }
      else {
        grenadesEids.mutate(@(v) v.$rawdelete(eid))
        totalGrenades.modify(@(v) v-1)
      }
    },
    onDestroy = function(_, eid, __) {
      if (eid in grenadesEids.value)
        grenadesEids.mutate(@(v) v.$rawdelete(eid))
      totalGrenades.modify(@(v) v-1)
    }
  },
  {
    comps_ro = [
      ["item__grenadeType", ecs.TYPE_STRING],
      ["item__grenadeLikeType", ecs.TYPE_STRING, null],
    ],
    comps_track = [
      ["item__containerOwnerEid", ecs.TYPE_EID],
      ["item__humanOwnerEid", ecs.TYPE_EID],
    ],
    comps_rq = ["watchedPlayerItem"]
  }
)

return {
  grenadesEids
  totalGrenades
}