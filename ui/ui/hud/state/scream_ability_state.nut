import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let screamAbilitySpawnTime = Watched(0)
let screamAbilitylastFailedUseTime = Watched(0)

ecs.register_es("scream_ability_state_timings_ui_es", {
  [["onChange", "onInit"]] = function(_eid,comp) {
    screamAbilitySpawnTime.set(comp.hero_scream_ability__spawnTime)
    screamAbilitylastFailedUseTime.set(comp.hero_scream_ability__lastFailedUseTime)
  }

}, {
  comps_track = [
    ["hero_scream_ability__spawnTime", ecs.TYPE_FLOAT],
    ["hero_scream_ability__lastFailedUseTime", ecs.TYPE_FLOAT],
  ]
  comps_rq=["hero"]
})


return {
  screamAbilitySpawnTime
  screamAbilitylastFailedUseTime
}
