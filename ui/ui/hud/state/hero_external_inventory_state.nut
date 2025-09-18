from "%ui/hud/state/inventory_items_es.nut" import updateEidInventoryContainer
from "%ui/hud/state/item_info.nut" import get_item_info
from "dasevents" import NotifyItemRecognitionStarted
from "dagor.debug" import debug
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { EXTERNAL_ITEM_CONTAINER } = require("%ui/hud/menus/components/inventoryItemTypes.nut")

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
let externalInventoryContainerOwnerEid = Watched(ecs.INVALID_ENTITY_ID)
let externalInventoryIsEquipment = Watched(false)


function updateExternalInventoryState(_eid, comp) {
  prevExternalInventoryEid.set(externalInventoryEid.get())
  externalInventoryEid.set(comp.external_inventory_interactor__clientInventoryEid)
}

ecs.register_es("external_inventory_interactor_state_ui",
  {
    [["onInit", "onChange"]] = updateExternalInventoryState
  },
  {
    comps_rq=["watchedByPlr"]
    comps_track=[
      ["external_inventory_interactor__clientInventoryEid", ecs.TYPE_EID]
    ]
  }
)

let trackExternalInventoryQuery = ecs.SqQuery("external_inventory_items_ui_Query", {
  comps_ro=[
    ["item__name", ecs.TYPE_STRING, null],
    ["itemContainer__name", ecs.TYPE_STRING, null],
    ["itemContainer__questName", ecs.TYPE_STRING, null],
    ["itemContainer", ecs.TYPE_EID_LIST],
    ["human_inventory__maxVolume", ecs.TYPE_INT],
    ["human_inventory__currentVolume", ecs.TYPE_INT],
    ["human_inventory__currentWeight", ecs.TYPE_FLOAT],
    ["itemContainer__uiItemsMergeEnabled", ecs.TYPE_BOOL, true],
    ["itemContainer__uiItemsSortingEnabled", ecs.TYPE_BOOL, true],
    ["itemContainer__uiItemsOverrideSortingPriority", ecs.TYPE_BOOL, false],
    ["item__containerOwnerEid", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID],
    ["equipment_item", ecs.TYPE_TAG, null]
  ]
})

function trackExternalInventory(eid, comp){
  if (eid != externalInventoryEid.get())
    return

  let items = comp[EXTERNAL_ITEM_CONTAINER.containerName]?.getAll() ?? []
  updateEidInventoryContainer(externalInventoryItems, items)

  externalInventoryName.set(comp.item__name ?? comp.itemContainer__name)
  externalInventoryQuestName.set(comp?.itemContainer__questName)
  externalInventoryMaxVolume.set(comp.human_inventory__maxVolume)
  externalInventoryCurrentVolume.set(comp.human_inventory__currentVolume)
  externalInventoryCurrentWeight.set(comp.human_inventory__currentWeight)
  externalInventoryItemsMergeEnabled.set(comp.itemContainer__uiItemsMergeEnabled)
  externalInventoryItemsSortingEnabled.set(comp.itemContainer__uiItemsSortingEnabled)
  externalInventoryItemsOverrideSortingPriority.set(comp.itemContainer__uiItemsOverrideSortingPriority)
  externalInventoryContainerOwnerEid.set(comp?.item__containerOwnerEid)
  externalInventoryIsEquipment.set(comp?.equipment_item)
}

externalInventoryEid.subscribe_with_nasty_disregard_of_frp_update(function(v){
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
      ["human_inventory__maxVolume", ecs.TYPE_INT],
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
      if (externalInventoryEid.get() != ecs.INVALID_ENTITY_ID &&
          comp.item__containerOwnerEid == externalInventoryEid.get()){
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
            
            
            debug($"[Recognizable Items] Item {eid} is not found in external inventory ({externalInventoryEid.get()}) items!")
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
  externalInventoryContainerOwnerEid
  externalInventoryIsEquipment
}
