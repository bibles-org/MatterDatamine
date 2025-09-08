import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {isDowned} = require("%ui/hud/state/health_state.nut")
let {bodyParts} = require("%ui/hud/state/human_damage_model_state.nut")
let { isSwimming } = require("%ui/hud/state/hero_water_state.nut")

let hasSelfRevives = Watched(false)
let hasInjectors = Watched(false)
let hasAmpoules = Watched(false)

ecs.register_es("track_watched_hero_heal_count", {
  [["onInit", "onChange"]] = function(_evt, comps) {
    hasSelfRevives.set(comps.ui__hasSelfRevives)
    hasInjectors.set(comps.ui__hasInjectors)
    hasAmpoules.set(comps.ui__hasAmpoules)
  }
  onDestroy = function(_evt,_comps) {
    hasSelfRevives.set(false)
    hasInjectors.set(false)
    hasAmpoules.set(false)
  }
},{
  comps_rq = ["watchedByPlr"],
  comps_track = [["ui__hasSelfRevives", ecs.TYPE_BOOL],
                 ["ui__hasInjectors", ecs.TYPE_BOOL],
                 ["ui__hasAmpoules", ecs.TYPE_BOOL]]
})

let healingDesc = Computed(function() {
  if (isSwimming.get())
    return null
  let haveBrokenBodypart = bodyParts.get().reduce(@(acc, part) acc || part.hp == 0, false)
  if (isDowned.get()){
    if (hasSelfRevives.get())
      return "tips/heal/use_painkiller"
  }
  else if ((haveBrokenBodypart || !hasAmpoules.get()) && hasInjectors.get())
    return "tips/heal/use_injector"
  else if (hasAmpoules.get())
    return "tips/heal/use_ampoule"

  return null
})

return {
  healingDesc
}
