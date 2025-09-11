from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs
let { nexusAllyTeam, nexusPlayerSpawnCount } = require("%ui/hud/state/nexus_mode_state.nut")

let isNexusDelayedSpawnInUse = Watched(false)
let isNexusDelayedSpawnFirstIsInstant = Watched(false)
let nexusNextDelayedSpawnAt = Watched(-1.0)

let isNexusDelayedSpawn = Computed(@() isNexusDelayedSpawnInUse.get() && (nexusPlayerSpawnCount.get() != 0 || !isNexusDelayedSpawnFirstIsInstant.get()))

ecs.register_es("nexus_spawn_track_instant_spawn", {
  onInit = function(_evt, _eid, comp) {
    if (comp.nexus_spawn_rules__team != nexusAllyTeam.get())
      return
    isNexusDelayedSpawnInUse.set(false)
    isNexusDelayedSpawnFirstIsInstant.set(false)
  },
},
{
  comps_ro = [
    ["nexus_spawn_rules__team", ecs.TYPE_INT]
  ]
  comps_no = [
    ["nexus_disable", ecs.TYPE_TAG],
    ["nexus_spawn_rules__at", ecs.TYPE_FLOAT]
  ]
},
{
  tags = "gameClient"
})

ecs.register_es("nexus_spawn_track_delayed_spawn", {
  [["onChange", "onInit"]] = function(_evt, _eid, comp) {
    if (comp.nexus_spawn_rules__team != nexusAllyTeam.get())
      return
    isNexusDelayedSpawnInUse.set(true)
    isNexusDelayedSpawnFirstIsInstant.set(comp.nexus_spawn_rules_group_first_spawn_is_instant_and_individual != null)
    nexusNextDelayedSpawnAt.set(comp.nexus_spawn_rules__at)
  },
  onDestroy = function(_evt, _eid, _comp) {
    nexusNextDelayedSpawnAt.set(-1.0)
  }
},
{
  comps_ro = [
    ["nexus_spawn_rules__team", ecs.TYPE_INT],
    ["nexus_spawn_rules_group_first_spawn_is_instant_and_individual", ecs.TYPE_TAG, null]
  ]
  comps_track=[
    ["nexus_spawn_rules__at", ecs.TYPE_FLOAT]
  ]
  comps_no = [
    ["nexus_disable", ecs.TYPE_TAG]
  ]
},
{
  tags = "gameClient"
})

return {
  isNexusDelayedSpawn
  nexusNextDelayedSpawnAt
}
