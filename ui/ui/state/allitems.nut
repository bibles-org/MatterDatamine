from "%ui/devInfo.nut" import addTabToDevInfo

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let allItems = Watched([])
let loadoutItems = Watched([])
let stashVolume = Watched(0)
let stashMaxVolume = Watched(0)
let stashEid = Watched(ecs.INVALID_ENTITY_ID)

addTabToDevInfo("[PLAYER BASE INFO] allItems", allItems)
addTabToDevInfo("[PLAYER BASE INFO] loadoutItems", loadoutItems)

ecs.register_es("track_all_player_items_on_base_es",
  {
    [["onInit", "onChange"]] = @(_eid, comp) allItems.set(comp.player_profile__allItems.getAll())
    onDestroy = @(_eid, _comp) allItems.set([])
  },
  { comps_track = [["player_profile__allItems", ecs.TYPE_ARRAY]]}, {}
)

ecs.register_es("track_all_loadout_items_on_base_es",
  {
    [["onInit", "onChange"]] = @(_eid, comp) loadoutItems.set(comp.player_profile__loadout.getAll())
    onDestroy = @(_eid, _comp) loadoutItems.set([])
  },
  { comps_track = [["player_profile__loadout", ecs.TYPE_ARRAY]]}, {}
)

ecs.register_es("track_stash_volume",
  {
    [["onInit", "onChange"]] = function(_eid, comp) {
      if (comp.inventory__name == "stash") {
        stashVolume.set(comp.human_inventory__currentVolume)
        stashMaxVolume.set(comp.human_inventory__maxVolume)
        stashEid.set(comp.eid)
      }
    }
    onDestroy = function(_eid, comp) {
      if (comp.inventory__name == "stash") {
        stashVolume.set(-1)
        stashMaxVolume.set(-1)
        stashEid.set(ecs.INVALID_ENTITY_ID)
      }
    }
  },
  {
    comps_ro=[
      ["eid", ecs.TYPE_EID],
      ["inventory__name", ecs.TYPE_STRING]
    ],
    comps_track = [
      ["human_inventory__maxVolume", ecs.TYPE_INT],
      ["human_inventory__currentVolume", ecs.TYPE_INT]
    ]
  },
  {}
)

return {
  loadoutItems
  allItems
  stashItems = Computed(@() allItems.get().filter(@(i) (i?.slotName ?? "") == "stash"))
  stashVolume
  stashMaxVolume
  stashEid
}