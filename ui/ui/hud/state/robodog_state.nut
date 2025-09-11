import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { get_controlled_hero } = require("%dngscripts/common_queries.nut")

let haveRobodog = Watched(false)
let herosRobodogs = Watched({})
let robodogNear = Computed(@() herosRobodogs.get().filter(@(v) v == true).len())


ecs.register_es("change_owner_robodog", {
  [["onInit", "onChange"]] = function(eid, comp) {
    let herosRobodog = comp.ownerEid == get_controlled_hero()
    if (herosRobodog && comp.isAlive)
      herosRobodogs.mutate(@(v) v[eid] <- comp.signal_grenade_device__extractWithOwner)
    else if (herosRobodogs.get()?[eid] != null)
      herosRobodogs.mutate(@(v) v.$rawdelete(eid))
    haveRobodog.set(herosRobodogs.get().len() != 0)
  }
  onDestroy = function(eid, comp) {
    let herosRobodog = comp.ownerEid == get_controlled_hero()
    if (herosRobodog && (herosRobodogs.get()?[eid] ?? false)){
      herosRobodogs.mutate(@(v) v.$rawdelete(eid))
    }
    haveRobodog.set(herosRobodogs.get().len() != 0)
  }
},
{
  comps_rq = [["robodog__hacker", ecs.TYPE_EID]],
  comps_track = [
    ["ownerEid", ecs.TYPE_EID],
    ["signal_grenade_device__extractWithOwner", ecs.TYPE_BOOL],
    ["isAlive", ecs.TYPE_BOOL]
  ],
})

return {
  haveRobodog,
  robodogNear
}