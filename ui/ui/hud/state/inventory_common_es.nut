import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let maxVolume = Watched(0.0)
ecs.register_es("capacity_volume_es",{
  [["onChange", "onInit"]] = @(_eid, comp) maxVolume.set(comp["human_inventory__maxVolumeInt"] / 10.0)
},{comps_track = [["human_inventory__maxVolumeInt", ecs.TYPE_INT, 0]], comps_rq = ["watchedByPlr"]})

let defaultMaxVolume = Watched(0.0)
ecs.register_es("default_capacity_volume_es",{
  [["onChange", "onInit"]] = @(_eid, comp) defaultMaxVolume.set(comp["human_inventory__maxVolume"] / 10.0)
},{comps_track = [["human_inventory__maxVolume", ecs.TYPE_FLOAT, 0]], comps_rq = ["watchedByPlr"]})

let canPickupItems = Watched(false)
ecs.register_es("canPickupItems_es",{
  [["onChange", "onInit"]] = @(_eid,comp) canPickupItems(comp["human__canPickupItems"]),
  onDestroy = @(_eid, _comp) canPickupItems(false)
}, {comps_track=[["human__canPickupItems",ecs.TYPE_BOOL]], comps_rq=["human_input"]})

let canUseItems = Watched(false)
ecs.register_es("canUseItems_es",{
  [["onChange", "onInit"]] = @(_eid,comp) canUseItems(comp["human_inventory__canUseItems"]),
  onDestroy = @(_eid, _comp) canUseItems(false)
}, {comps_track=[["human_inventory__canUseItems",ecs.TYPE_BOOL]], comps_rq=["human_input"]})

let canModifyInventory = Watched(false)
ecs.register_es("canModifyInventory_es",{
  [["onChange", "onInit"]] = @(_eid,comp) canModifyInventory(comp["human_inventory__canModifyInventory"]),
  onDestroy = @(_eid, _comp) canModifyInventory(false)
}, {comps_track=[["human_inventory__canModifyInventory",ecs.TYPE_BOOL]], comps_rq=["human_input"]})

let canHeal = Watched(false)
ecs.register_es("canHeal_es",{
  [["onChange", "onInit"]] = @(_eid,comp) canHeal(comp["human_inventory__canHeal"]),
  onDestroy = @(_eid, _comp) canHeal(false)
}, {comps_track=[["human_inventory__canHeal",ecs.TYPE_BOOL]], comps_rq=["watchedByPlr"]})

let canLoadCharges = Watched(false)
ecs.register_es("canLoadCharges_es",{
  [["onChange", "onInit"]] = @(_eid,comp) canLoadCharges(comp["human_inventory__canLoadCharges"]),
  onDestroy = @(_eid, _comp) canLoadCharges(false)
}, {comps_track=[["human_inventory__canLoadCharges",ecs.TYPE_BOOL]], comps_rq=["watchedByPlr"]})


let carriedVolume = Watched(0.0)
let carriedWeight = Watched(0.0)
ecs.register_es("hero_state_inv_stats_ui_es",
  {
    [["onInit","onChange"]] = function(_eid,comp) {
      carriedVolume.set(comp["human_inventory__currentVolume"] / 10.0)
      carriedWeight.set(comp["human_inventory__currentWeight"])
    }
  },
  {
    comps_track=[
      ["human_inventory__currentVolume", ecs.TYPE_INT, 0.0],
      ["human_inventory__currentWeight", ecs.TYPE_FLOAT, 0.0]
    ]
    comps_rq=["watchedByPlr"]
  }
)

let didItemDataChange = function(oldData, newData) {
  return (oldData == null || oldData.countPerItem != newData.countPerItem || oldData.eid != newData.eid ||
      oldData.count != newData.count || oldData?.id != newData?.id || oldData.recognizeTime != newData.recognizeTime || oldData.charges != newData.charges ||
      oldData.ammoCount != newData.ammoCount || oldData.recognizeTimeLeft != newData.recognizeTimeLeft ||
      oldData.isDelayedMoveMod != newData.isDelayedMoveMod || oldData.canDrop != newData.canDrop ||
      oldData?.noSuitableItemForPresetFoundCount != newData?.noSuitableItemForPresetFoundCount || 
      newData?.dataChanged ||
      !isEqual(oldData?.modInSlots, newData?.modInSlots) || oldData?.countKnown != newData?.countKnown ||
      !isEqual(oldData?.itemContainerItems, newData?.itemContainerItems));
}

return {
  maxVolume
  defaultMaxVolume
  canPickupItems
  canUseItems
  canModifyInventory
  carriedVolume
  carriedWeight
  didItemDataChange
  canLoadCharges
  canHeal
}