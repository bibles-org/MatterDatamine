import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *
let { activateShowWeapons, activateShowWeaponsTimer } = require("%ui/hud/player_info/show_weapon_state.nut")

let checkAmmoMarkers = Watched({})

ecs.register_es("check_ammo_mark_state_ui_es", {
  [["onInit"]] = function(eid, comp) {
    if (checkAmmoMarkers.get().len() == 0)
      activateShowWeapons()

    checkAmmoMarkers.mutate(@(v) v[eid] <- {
      loc = comp.check_weapon_mark__loc
      locData = comp.check_weapon_mark__locData.getAll()
    })
  }
  onDestroy = function(eid,_comp) {
    if (eid in checkAmmoMarkers.get())
      checkAmmoMarkers.mutate(@(v) v.$rawdelete(eid))
    if (checkAmmoMarkers.get().len() == 0)
      activateShowWeaponsTimer()
  }
}, {
  comps_ro = [
    ["check_weapon_mark__loc", ecs.TYPE_STRING],
    ["check_weapon_mark__locData", ecs.TYPE_OBJECT],
    ["transform", ecs.TYPE_MATRIX]
  ]
})

return { checkAmmoMarkers }
