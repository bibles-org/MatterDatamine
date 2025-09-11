from "%ui/hud/tips/tipComponent.nut" import tipCmp

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { isAlive } = require("%ui/hud/state/health_state.nut")
let { get_controlled_hero } = require("%dngscripts/common_queries.nut")

let enableShowTipBipod = Watched(false)

ecs.register_es("catch_enable_place_bipod_es", {
  [["onInit", "onChange"]] = function(_evt,eid,comp){
      if (get_controlled_hero() == eid) {
        if (comp.bipod__enabled || !comp.bipod__haveBipodOnGun || comp.bipod__delayAt > 0.0)
          enableShowTipBipod.set(false)
        else
          enableShowTipBipod.set(comp.human_net_phys__isCrawl ? comp.bipod__placeCrawl : comp.bipod__placeable)
      }
    }
  onDestroy = @(...) enableShowTipBipod.set(false),
  },
  {
    comps_track = [["bipod__delayAt", ecs.TYPE_FLOAT],
                   ["bipod__placeable", ecs.TYPE_BOOL],
                   ["bipod__placeCrawl", ecs.TYPE_BOOL],
                   ["bipod__haveBipodOnGun", ecs.TYPE_BOOL],
                   ["bipod__enabled", ecs.TYPE_BOOL],
                   ["human_net_phys__isCrawl", ecs.TYPE_BOOL]]
  },
  {tags = "gameClient"}
)

let showSwitchOnBipod = Computed(function() {
  return (isAlive.get()
    && enableShowTipBipod.get())
})

let tipBipod = tipCmp({
  inputId = "Human.BipodToggle"
  text = loc("hint/use_bipod")
})


return @() {
  watch = showSwitchOnBipod
  children = showSwitchOnBipod.get() ? tipBipod : null
}