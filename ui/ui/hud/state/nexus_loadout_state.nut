from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { localPlayerEid } = require("%ui/hud/state/local_player.nut")

let allNexusLoadouts = Watched({})

ecs.register_es("track_nexus_players_loadout_selection_es", {
  [["onInit", "onChange"]]  = function(_evt, _eid, comp) {
    let id = comp.nexus_loadouts__owner
    local loadouts = comp.nexus_loadouts__allLoadouts.getAll()
    foreach (loadout in loadouts) {
      if (loadout?.is_agency_loadout != null) {
        loadout.name = loc(loadout.name)
      }
    }
    allNexusLoadouts.mutate(@(v) v[id] <- loadouts)
  }
  onDestroy = function(...) {
    allNexusLoadouts.set({})
  }
}, {
  comps_track = [
    ["nexus_loadouts__allLoadouts", ecs.TYPE_ARRAY],
    ["nexus_loadouts__owner", ecs.TYPE_EID]
  ]
}, {tags = "gameClient"})

return {
  allNexusLoadouts
  allLocalPlayerNexusLoadouts = Computed(@() allNexusLoadouts.get()?[localPlayerEid.get()] ?? [])
}
