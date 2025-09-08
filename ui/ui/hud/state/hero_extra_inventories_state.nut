import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let backpackEid = Watched(0)
let safepackEid = Watched(0)

let backpackMaxVolume = Watched(0.0)
let backpackCurrentVolume = Watched(0.0)
let safepackMaxVolume = Watched(0.0)
let safepackCurrentVolume = Watched(0.0)
let safepackYVisualSize = Watched(null)
let backpackCurrentWeight = Watched(0.0)
let backpackItemsMergeEnabled = Watched(true)
let backpackItemsSortingEnabled = Watched(true)
let backpackItemsOverrideSortingPriority = Watched(false)
let backpackItemRecognitionEnabled = Watched(false) 
let backpackUniqueId = Watched("0")
let safepackUniqueId = Watched("0")

ecs.register_es("backpack_interactor_state_ui",
  {
    [["onInit", "onChange"]] = @(_eid, comp) backpackEid(comp.militant_extra_inventories__backpackEid)
  },
  {
    comps_rq=["watchedByPlr"]
    comps_track=[
      ["militant_extra_inventories__backpackEid", ecs.TYPE_EID]
    ]
  }
)


ecs.register_es("safepack_interactor_state_ui",
  {
    [["onInit", "onChange"]] = @(_eid, comp) safepackEid(comp.militant_extra_inventories__safepackEid)
  },
  {
    comps_rq=["watchedByPlr"]
    comps_track=[
      ["militant_extra_inventories__safepackEid", ecs.TYPE_EID]
    ]
  }
)

let trackBackpackComponents = {
  comps_ro=[
    ["human_inventory__maxVolumeInt", ecs.TYPE_INT],
    ["human_inventory__currentVolume", ecs.TYPE_INT],
    ["human_inventory__currentWeight", ecs.TYPE_FLOAT],
    ["itemContainer__uiItemsMergeEnabled", ecs.TYPE_BOOL, true],
    ["itemContainer__uiItemsSortingEnabled", ecs.TYPE_BOOL, true],
    ["itemContainer__uiItemsOverrideSortingPriority", ecs.TYPE_BOOL, false],
    ["uniqueId", ecs.TYPE_STRING, "0"],
    ["safepack__visualYSize", ecs.TYPE_INT, null]
  ]
}

let trackBackpackQuery = ecs.SqQuery("extra_inventories_stats_ui_Query", trackBackpackComponents)

function trackBackpack(eid, comp){
  if (eid != backpackEid.value)
    return
  backpackMaxVolume(comp.human_inventory__maxVolumeInt / 10.0)
  backpackCurrentVolume(comp.human_inventory__currentVolume / 10.0)
  backpackCurrentWeight(comp.human_inventory__currentWeight)
  backpackItemsMergeEnabled(comp.itemContainer__uiItemsMergeEnabled)
  backpackItemsSortingEnabled(comp.itemContainer__uiItemsSortingEnabled)
  backpackItemsOverrideSortingPriority(comp.itemContainer__uiItemsOverrideSortingPriority)
  backpackUniqueId.set(comp.uniqueId)
}

function trackSafepack(eid, comp){
  if (eid != safepackEid.value)
    return

  safepackMaxVolume.set(comp.human_inventory__maxVolumeInt / 10.0)
  safepackCurrentVolume.set(comp.human_inventory__currentVolume / 10.0)
  safepackUniqueId.set(comp?.uniqueId ?? "0")
  safepackYVisualSize.set(comp?.safepack__visualYSize)
}


let setItemRecognitionEnabledQuery = ecs.SqQuery("external_inventory_set_item_recognition_enabled_ui_Query", {
  comps_rw=[["inventory__itemRecognitionEnabled", ecs.TYPE_BOOL]]
})

function setItemRecognitionEnabledECSValue(v){
  setItemRecognitionEnabledQuery.perform(backpackEid.value, @(_, comp) comp.inventory__itemRecognitionEnabled = v)
}


backpackEid.subscribe(function(v){
  if (v != ecs.INVALID_ENTITY_ID){
    trackBackpackQuery.perform(v, trackBackpack)
    setItemRecognitionEnabledECSValue(backpackItemRecognitionEnabled.value)
  }
})


safepackEid.subscribe(function(v){
  if (v != ecs.INVALID_ENTITY_ID){
    trackBackpackQuery.perform(v, trackSafepack)
    setItemRecognitionEnabledECSValue(backpackItemRecognitionEnabled.value)
  }
})

backpackItemRecognitionEnabled.subscribe(setItemRecognitionEnabledECSValue)


ecs.register_es("late_init_extra_inventory_settings_ui", 
  {
    [["onInit"]] = function(eid, comp){
      trackBackpack(eid, comp)
      trackSafepack(eid, comp)
    }
  },
  trackBackpackComponents
)

ecs.register_es("extra_inventories_stats_ui_es",
  {
    [["onInit", "onChange"]] = function(eid, comp){
      trackBackpack(eid, comp)
      trackSafepack(eid, comp)
    }
  },
  {
    comps_rq = [
      ["inventory__name", ecs.TYPE_STRING]
    ]
    comps_track = trackBackpackComponents.comps_ro
  }
)

return {
  backpackEid
  safepackEid
  backpackMaxVolume
  backpackCurrentVolume
  safepackMaxVolume
  safepackCurrentVolume
  backpackCurrentWeight
  backpackItemsMergeEnabled
  backpackItemsSortingEnabled
  backpackItemsOverrideSortingPriority
  backpackItemRecognitionEnabled
  backpackUniqueId
  safepackUniqueId
  safepackYVisualSize
}
