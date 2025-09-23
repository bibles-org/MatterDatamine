import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let maxVolume = Watched(0.0)
ecs.register_es("capacity_volume_es",{
  onInit = function(_eid, comp){
    maxVolume.set(comp["human_inventory__maxVolume"])
  }
  onChange = @(_eid, comp) maxVolume.set(comp["human_inventory__maxVolume"])
},{comps_track = [["human_inventory__maxVolume", ecs.TYPE_INT, 0]], comps_rq = ["watchedByPlr"]})

let canPickupItems = Watched(false)
ecs.register_es("canPickupItems_es",{
  [["onChange", "onInit"]] = @(_eid,comp) canPickupItems.set(comp["human__canPickupItems"]),
  onDestroy = @(_eid, _comp) canPickupItems.set(false)
}, {comps_track=[["human__canPickupItems",ecs.TYPE_BOOL]], comps_rq=["human_input"]})

let canUseItems = Watched(false)
ecs.register_es("canUseItems_es",{
  [["onChange", "onInit"]] = @(_eid,comp) canUseItems.set(comp["human_inventory__canUseItems"]),
  onDestroy = @(_eid, _comp) canUseItems.set(false)
}, {comps_track=[["human_inventory__canUseItems",ecs.TYPE_BOOL]], comps_rq=["human_input"]})

let canModifyInventory = Watched(false)
ecs.register_es("canModifyInventory_es",{
  [["onChange", "onInit"]] = @(_eid,comp) canModifyInventory.set(comp["human_inventory__canModifyInventory"]),
  onDestroy = @(_eid, _comp) canModifyInventory.set(false)
}, {comps_track=[["human_inventory__canModifyInventory",ecs.TYPE_BOOL]], comps_rq=["human_input"]})

let canHeal = Watched(false)
ecs.register_es("canHeal_es",{
  [["onChange", "onInit"]] = @(_eid,comp) canHeal.set(comp["human_inventory__canHeal"]),
  onDestroy = @(_eid, _comp) canHeal.set(false)
}, {comps_track=[["human_inventory__canHeal",ecs.TYPE_BOOL]], comps_rq=["human_input"]})

let canLoadCharges = Watched(false)
ecs.register_es("canLoadCharges_es",{
  [["onChange", "onInit"]] = @(_eid,comp) canLoadCharges.set(comp["human_inventory__canLoadCharges"]),
  onDestroy = @(_eid, _comp) canLoadCharges.set(false)
}, {comps_track=[["human_inventory__canLoadCharges",ecs.TYPE_BOOL]], comps_rq=["human_input"]})


let carriedVolume = Watched(0.0)
let carriedWeight = Watched(0.0)
ecs.register_es("hero_state_inv_stats_ui_es",
  {
    [["onInit","onChange"]] = function(_eid,comp) {
      carriedVolume.set(comp["human_inventory__currentVolume"])
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
      newData?.dataChanged || oldData.volume != newData.volume ||
      !isEqual(oldData?.modInSlots, newData?.modInSlots) || oldData?.countKnown != newData?.countKnown ||
      !isEqual(oldData?.itemContainerItems, newData?.itemContainerItems) ||
      oldData?.nexusCost != newData?.nexusCost
    );
}

return {
  maxVolume
  canPickupItems
  canUseItems
  canModifyInventory
  carriedVolume
  carriedWeight
  didItemDataChange
  canLoadCharges
  canHeal
}
