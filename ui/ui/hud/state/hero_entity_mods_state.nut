import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {EventOnModsChanged} = require("gameevents")

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
    after="entity_mod_values_init,entity_mod_effect_calc"
  }
)

function getHeroModValue(modName, defaultVal) {
  return heroEntityMods.get()?[modName]?.value ?? defaultVal
}

return {
  getHeroModValue
}