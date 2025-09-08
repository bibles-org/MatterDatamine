import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let {EXTERNAL_ITEM_CONTAINER} = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let {updateEidInventoryContainer} = require("%ui/hud/state/inventory_items_es.nut")
let { trackInventory } = require("%ui/hud/state/unified_inventory_state.nut")
let {get_item_info} = require("%ui/hud/state/item_info.nut")
let { NotifyItemRecognitionStarted } = require("dasevents")
let { debug } = require("dagor.debug")

let externalInventoryEid = Watched(0)
let prevExternalInventoryEid = Watched(0)
let externalInventoryItems = mkWatched(persist, "externalInventoryItems", [])

let externalInventoryName = Watched(null)
let externalInventoryQuestName = Watched(null)
let externalInventoryMaxVolume = Watched(0.0)
let externalInventoryCurrentVolume = Watched(0.0)
let externalInventoryCurrentWeight = Watched(0.0)
let externalInventoryItemsMergeEnabled = Watched(true)
let externalInventoryItemsSortingEnabled = Watched(true)
let externalInventoryItemsOverrideSortingPriority = Watched(false)


function updateExternalInventoryState(_eid, comp) {
  prevExternalInventoryEid.set(externalInventoryEid.value)
  externalInventoryEid.set(comp.external_inventory_interactor__inventoryEid)
}

ecs.register_es("external_inventory_interactor_state_ui",
  {
    [["onInit", "onChange"]] = updateExternalInventoryState
  },
  {
    comps_rq=["watchedByPlr"]
    comps_track=[
      ["external_inventory_interactor__inventoryEid", ecs.TYPE_EID]
    ]
  }
)

ecs.SqQuery("external_inventory_interactor_state_ui_init_Query", {
  comps_rq=["watchedByPlr"]
  comps_ro=[
    ["external_inventory_interactor__inventoryEid", ecs.TYPE_EID]
  ]
}).perform(updateExternalInventoryState)


let trackExternalInventoryQuery = ecs.SqQuery("external_inventory_items_ui_Query", {
  comps_ro=[
    ["item__name", ecs.TYPE_STRING, null],
    ["itemContainer__name", ecs.TYPE_STRING, null],
    ["itemContainer__questName", ecs.TYPE_STRING, null],
    ["itemContainer", ecs.TYPE_EID_LIST],
    ["human_inventory__maxVolumeInt", ecs.TYPE_INT],
    ["human_inventory__currentVolume", ecs.TYPE_INT],
    ["human_inventory__currentWeight", ecs.TYPE_FLOAT],
    ["itemContainer__uiItemsMergeEnabled", ecs.TYPE_BOOL, true],
    ["itemContainer__uiItemsSortingEnabled", ecs.TYPE_BOOL, true],
    ["itemContainer__uiItemsOverrideSortingPriority", ecs.TYPE_BOOL, false]
  ]
})

function trackExternalInventory(eid, comp){
  if (eid != externalInventoryEid.get())
    return

  let items = comp[EXTERNAL_ITEM_CONTAINER.containerName]?.getAll() ?? []
  updateEidInventoryContainer(ecs.calc_hash(EXTERNAL_ITEM_CONTAINER.containerName),
                              externalInventoryItems, items)

  trackInventory(eid, comp)
  externalInventoryName(comp.item__name ?? comp.itemContainer__name)
  externalInventoryQuestName(comp?.itemContainer__questName)
  externalInventoryMaxVolume(comp.human_inventory__maxVolumeInt / 10.0)
  externalInventoryCurrentVolume(comp.human_inventory__currentVolume / 10.0)
  externalInventoryCurrentWeight(comp.human_inventory__currentWeight)
  externalInventoryItemsMergeEnabled(comp.itemContainer__uiItemsMergeEnabled)
  externalInventoryItemsSortingEnabled(comp.itemContainer__uiItemsSortingEnabled)
  externalInventoryItemsOverrideSortingPriority(comp.itemContainer__uiItemsOverrideSortingPriority)
}

externalInventoryEid.subscribe(function(v){
  if (v != ecs.INVALID_ENTITY_ID)
    trackExternalInventoryQuery.perform(v, trackExternalInventory)
})


ecs.register_es("external_inventory_items_ui_es",
  {
    [["onInit", "onChange"]] = trackExternalInventory,
  },
  {
    comps_rq = [
      ["external_inventory_container", ecs.TYPE_TAG]
    ]
    comps_track = [
      ["itemContainer", ecs.TYPE_EID_LIST],
      ["human_inventory__maxVolumeInt", ecs.TYPE_INT],
      ["human_inventory__currentVolume", ecs.TYPE_INT],
      ["human_inventory__currentWeight", ecs.TYPE_FLOAT]
    ]
    comps_ro = [
      ["item__name", ecs.TYPE_STRING, null],
      ["itemContainer__name", ecs.TYPE_STRING, null],
      ["itemContainer__uiItemsMergeEnabled", ecs.TYPE_BOOL, true],
      ["itemContainer__uiItemsSortingEnabled", ecs.TYPE_BOOL, true],
      ["itemContainer__uiItemsOverrideSortingPriority", ecs.TYPE_BOOL, false],
    ]
  }
)


ecs.register_es("update_single_external_inventory_item_ui_es",
  {
    [["onChange", NotifyItemRecognitionStarted]] = function(eid, comp){
      if (externalInventoryEid.value != ecs.INVALID_ENTITY_ID &&
          comp.item__containerOwnerEid == externalInventoryEid.value){
        externalInventoryItems.mutate(function(v){
          local itemFound = false
          for (local i = 0; i < v.len(); i++){
            if (v[i].eid == eid){
              v[i] = get_item_info(eid)
              itemFound = true
              break
            }
          }
          if (!itemFound) {
            
            
            debug($"[Recognizable Items] Item {eid} is not found in external inventory ({externalInventoryEid.value}) items!")
          }
        })
      }
    }
  },
  {
    comps_ro = [
      ["item__containerOwnerEid", ecs.TYPE_EID]
    ]
    comps_track = [
      ["item__recognizedByPlayers", ecs.TYPE_EID_LIST],
      ["ammo_holder__ammoCountKnown", ecs.TYPE_EID_LIST, null]
    ]
  }
)



return {
  externalInventoryEid
  prevExternalInventoryEid
  externalInventoryName
  externalInventoryQuestName
  externalInventoryItems
  externalInventoryMaxVolume
  externalInventoryCurrentVolume
  externalInventoryCurrentWeight
  externalInventoryItemsMergeEnabled
  externalInventoryItemsSortingEnabled
  externalInventoryItemsOverrideSortingPriority
}
