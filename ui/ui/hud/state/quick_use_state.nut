import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let questItemInUse = Watched(false)

ecs.register_es("quest_item_in_use_es", {
  [["onChange", "onInit"]] = function(_eid, comp){
    questItemInUse.set(comp.hero_ability__ultimateActivated)
  }
  onDestroy = function(_eid, _comp){
    questItemInUse.set(false)
  }
}, {
  comps_track = [[ "hero_ability__ultimateActivated", ecs.TYPE_BOOL ]]
  comps_rq=["hero"]
})

return {
  questItemInUse
}