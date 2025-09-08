import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let inventoryDataByEid = Watched({})

function trackInventory(eid, comp){
  inventoryDataByEid.mutate(@(v) v[eid] <- {
    maxVolume = comp.human_inventory__maxVolumeInt / 10.0
    volume = comp.human_inventory__currentVolume / 10.0
    isInfinite = comp.human_inventory__maxVolumeInt < 0
  })
}

function removeInventoryData(eid, _comp){
  inventoryDataByEid.mutate(@(v) v.rawdelete(eid))
}

ecs.register_es("track_hero_main_inventory_ui_es",
  {
    [["onInit", "onChange"]] = trackInventory
    onDestroy = removeInventoryData
  },
  {
    comps_rq = ["hero"]
    comps_track = [
      ["human_inventory__maxVolumeInt", ecs.TYPE_INT],
      ["human_inventory__currentVolume", ecs.TYPE_INT]
    ]
  }
)

ecs.register_es("track_hero_stash_inventory_ui_es",
  {
    [["onInit", "onChange"]] = trackInventory
    onDestroy = removeInventoryData
  },
  {
    comps_rq = ["stash_inventory__heroEid"]
    comps_track = [
      ["human_inventory__maxVolumeInt", ecs.TYPE_INT],
      ["human_inventory__currentVolume", ecs.TYPE_INT]
    ]
  }
)

ecs.register_es("track_secondary_hero_inventories_ui_es",
  {
    [["onInit", "onChange"]] = trackInventory
    onDestroy = removeInventoryData
  },
  {
    comps_rq = ["watchedPlayerItem"]
    comps_track = [
      ["human_inventory__maxVolumeInt", ecs.TYPE_INT],
      ["human_inventory__currentVolume", ecs.TYPE_INT]
    ]
  }
)

return {
  inventoryDataByEid
  trackInventory
}