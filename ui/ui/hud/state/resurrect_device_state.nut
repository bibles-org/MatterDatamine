import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { localPlayerTeam, localPlayerEid } = require("%ui/hud/state/local_player.nut")
let localResurrectionDevice = Watched(ecs.INVALID_ENTITY_ID)
let localResurrectionDeviceSelfDestroyAt = Watched(null)
let teammateRessurectDevices = Watched({})


let teammates_get_team_query = ecs.SqQuery("teammates_get_team_query", {
  comps_ro = [["team", ecs.TYPE_INT]]
})


ecs.register_es("track_respawn_device",
{
  onInit = function(eid, comp){
    if (comp.playerOwnerEid == localPlayerEid.get())
      localResurrectionDevice.set(eid)
    teammates_get_team_query.perform(comp.playerOwnerEid, function(_eid, playerComp) {
      if (localPlayerTeam.get() == playerComp.team)
        teammateRessurectDevices.mutate(@(resurrect_device) resurrect_device[comp.playerOwnerEid] <- {})
    })
  }
  onDestroy = function(_evt, eid, comp) {
    if (localResurrectionDevice.get() == eid) {
      localResurrectionDevice.set(ecs.INVALID_ENTITY_ID)
      localResurrectionDeviceSelfDestroyAt.set(null)
    }
    teammates_get_team_query.perform(comp.playerOwnerEid, function(_eid, playerComp) {
      if (localPlayerTeam.get() == playerComp.team)
        teammateRessurectDevices.mutate(function(resurrect_device) { resurrect_device.$rawdelete(comp.playerOwnerEid) })
    })
  }
},
{
  comps_rq = ["self_resurrection_device"]
  comps_ro = [ ["playerOwnerEid", ecs.TYPE_EID] ]
})


ecs.register_es("track_respawn_device_self_destruction_time",
{
  [["onInit", "onChange"]] = function(_eid, comp){
    if (comp.game_effect__attachedTo == localResurrectionDevice.get())
      localResurrectionDeviceSelfDestroyAt.set(comp.resurrect_device__destroyAt)
  }
  onDestroy = @(...) localResurrectionDeviceSelfDestroyAt.set(null)
},
{
  comps_ro = [ ["game_effect__attachedTo", ecs.TYPE_EID] ]
  comps_track = [ ["resurrect_device__destroyAt", ecs.TYPE_FLOAT] ]
}, { after="track_respawn_device" })


return {
  localResurrectionDevice,
  localResurrectionDeviceSelfDestroyAt,
  teammateRessurectDevices
}