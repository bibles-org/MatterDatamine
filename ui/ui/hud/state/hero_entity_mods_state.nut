from "gameevents" import EventOnModsChanged

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let heroEntityMods = Watched({})

ecs.register_es("hero_entity_mods_es",
  {
    [["onInit", EventOnModsChanged]] = function(_eid, comp) {
      heroEntityMods.set(comp.entity_mod_values.getAll())
    }
    onDestroy = @(_eid, _comp) heroEntityMods.set({})
  },
  {
    comps_ro=[["entity_mod_values", ecs.TYPE_OBJECT]],
    comps_rq=[["watchedByPlr", ecs.TYPE_EID]],
  },
  {
    after="after_entity_mods_apply_sync_point"
  }
)

function getHeroModValue(modName, defaultVal) {
  return heroEntityMods.get()?[modName]?.value ?? defaultVal
}

return {
  getHeroModValue
}