from "%dngscripts/sound_system.nut" import sound_play
from "%ui/helpers/ec_to_watched.nut" import mkFrameIncrementObservable
from "%ui/hud/state/item_info.nut" import getItemInfo, get_item_info
from "das.inventory" import is_quest_item_for_other_player, is_item_hidden_for_player
from "dasevents" import EventCapacityExceeded, NotifyItemRecognitionStarted
from "%ui/hud/state/inventory_common_es.nut" import didItemDataChange
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { item_comps } = require("%ui/hud/state/item_info.nut")
let { find_local_player } = require("%dngscripts/common_queries.nut")


let {inventoryItemsByEid, inventoryItemsByEidSetKeyVal, inventoryItemsByEidDeleteKey} = mkFrameIncrementObservable({}, "inventoryItemsByEid")
let {backpackItemsByEid, backpackItemsByEidSetKeyVal, backpackItemsByEidDeleteKey} = mkFrameIncrementObservable({}, "backpackItemsByEid")
let {safepackItemsByEid, safepackItemsByEidSetKeyVal, safepackItemsByEidDeleteKey} = mkFrameIncrementObservable({}, "safepackItemsByEid")
let {stashItemsByEid, stashItemsByEidSetKeyVal, stashItemsByEidDeleteKey} = mkFrameIncrementObservable({}, "stashItemsByEid")


let inventoryItemsMergeEnabled = Watched(true)
let inventoryItemsSortingEnabled = Watched(true)

let inventoryItems = Watched([])
let backpackItems = Watched([])
let safepackItems = Watched([])
let stashItems = Watched([])

function updateInventoryContainerCommon(inventory_items, items, get_item_info_cb) {
  let resInventory = []
  let localPlayerEid = find_local_player()
  foreach (item_desc in items){
    let item = get_item_info_cb(item_desc)
    if (item==null)
      continue
    if (is_quest_item_for_other_player(item.eid, localPlayerEid) || is_item_hidden_for_player(item.eid, localPlayerEid))
      continue
    resInventory.append(item)
  }
  let prevItems = inventory_items.get()

  local changed = false
  if (prevItems == null || prevItems.len() != resInventory.len())
    changed = true
  else {
    let count = resInventory.len()
    for(local i = 0; i < count; i++) {
      let item = resInventory[i]
      let oldItem = prevItems[i]

      if (didItemDataChange(oldItem, item)) {
        changed = true

        if (oldItem.recognizeTimeLeft > 0.0 && item.recognizeTimeLeft <= 0.0) {
          foreach (eid in item.eids)
            anim_start($"inventory_item_blink_{eid}")
          sound_play("ui_sounds/flag_unset")
        }
        break
      }
    }
  }

  if (changed){
    inventory_items.set(resInventory)
  }
}

function updateInventory(inventory_items, items) {
  updateInventoryContainerCommon(inventory_items, items, @(item_eid) item_eid)
}

function updateEidInventoryContainer(inventory_items, items) {
  updateInventoryContainerCommon(inventory_items, items, @(item_eid) get_item_info(item_eid))
}

let track_comps = [
  ["item__useTime", ecs.TYPE_FLOAT, null],
  ["item__volume", ecs.TYPE_INT, null],
  ["item__amount", ecs.TYPE_INT, null],
  ["item__currentBoxedItemCount", ecs.TYPE_INT, null],
  ["item__recognizedByPlayers", ecs.TYPE_EID_LIST, null],
  ["itemContainer", ecs.TYPE_EID_LIST, null],
  ["gun_mods__curModInSlots", ecs.TYPE_OBJECT, null],
  ["equipment_mods__curModInSlots", ecs.TYPE_OBJECT, null],
  ["am_storage__value", ecs.TYPE_INT, null],
  ["ammo_holder__ammoCountKnown", ecs.TYPE_EID_LIST, null],
  ["item__hp", ecs.TYPE_FLOAT, null]
]

ecs.register_es("inventory_items_ui_es",
  {
    [["onChange", "onInit"]] = function(eid, comp) {
      inventoryItemsByEidSetKeyVal(eid, getItemInfo(eid, comp))
    }
    onDestroy = function(eid, _comp) {
      inventoryItemsByEidDeleteKey(eid)
    }
  },
  {
    comps_rq = ["item_in_inventory"]
    comps_no = ["item_holder_in_weapon_load"]
    comps_ro = item_comps
    comps_track = track_comps
  }
)

ecs.register_es("stash_items_ui_es",
  {
    [["onChange", "onInit"]] = function(eid, comp) {
      let newInfo = getItemInfo(eid, comp)
      let currentInfo = stashItemsByEid.get()?[eid]
      if (didItemDataChange(currentInfo, newInfo))
        stashItemsByEidSetKeyVal(eid, newInfo)
    }
    onDestroy = function(eid, _comp) {
      stashItemsByEidDeleteKey(eid)
    }
  },
  {
    comps_rq = ["item_in_stash"]
    comps_no = ["item_holder_in_weapon_load"]
    comps_ro = item_comps
    comps_track = track_comps
  }
)

ecs.register_es("backpack_items_ui_es",
  {
    [["onChange", "onInit", NotifyItemRecognitionStarted]] = function(eid, comp) {
      backpackItemsByEidSetKeyVal(eid, getItemInfo(eid, comp))
    }
    onDestroy = function(eid, _comp) {
      backpackItemsByEidDeleteKey(eid)
    }
  },
  {
    comps_rq = ["item_in_backpack"]
    comps_no = ["item_holder_in_weapon_load"]
    comps_ro = item_comps
    comps_track = track_comps
  }
)

ecs.register_es("safepack_items_ui_es",
  {
    [["onChange", "onInit", NotifyItemRecognitionStarted]] = function(eid, comp) {
      safepackItemsByEidSetKeyVal(eid, getItemInfo(eid, comp))
    }
    onDestroy = function(eid, _comp) {
      safepackItemsByEidDeleteKey(eid)
    }
  },
  {
    comps_rq = ["item_in_safepack"]
    comps_no = ["item_holder_in_weapon_load"]
    comps_ro = item_comps
    comps_track = track_comps
  }
)

















ecs.register_es("inventory_items_on_capacity_exceeded_es",
  {
    [EventCapacityExceeded] = function(evt, _eid, _comp) {
      anim_start($"inventory_capacity_blink_{evt.containerEid}")
    }
  },
  {
    comps_rq = ["hero"]
  }
)

ecs.register_es("items_ammo_count_anim_start_es",
  {
    [["onChange", "onInit"]] = function(_evt, eid, comp) {
      let triggerName = comp.boxedItem != null && comp.boxed_item__template != null ?
        $"inventory_item_count_anim_{comp.boxed_item__template}_ow_{comp.item__containerOwnerEid}" :
        $"inventory_item_count_anim_{eid}"
      anim_start(triggerName)
    }
  },
  {
    comps_rq = ["watchedPlayerItem"],
    comps_ro = [
      ["item__containerOwnerEid",ecs.TYPE_EID],
      ["boxed_item__template",ecs.TYPE_STRING, null],
      ["boxedItem", ecs.TYPE_TAG, null]
    ],
    comps_track = [
      ["item__currentBoxedItemCount",ecs.TYPE_INT, null],
      ["item__amount", ecs.TYPE_INT, null],
      ["am_storage__value", ecs.TYPE_INT, null],
      ["item__hp", ecs.TYPE_FLOAT, null]
    ]
  }
)

inventoryItemsByEid.subscribe_with_nasty_disregard_of_frp_update(@(v) updateInventory(inventoryItems, v))
backpackItemsByEid.subscribe_with_nasty_disregard_of_frp_update(@(v) updateInventory(backpackItems, v))
safepackItemsByEid.subscribe_with_nasty_disregard_of_frp_update(@(v) updateInventory(safepackItems, v))
stashItemsByEid.subscribe_with_nasty_disregard_of_frp_update(@(v) updateInventory(stashItems, v))

ecs.register_es("inventory_item_container_ui_es",
  {
    [["onInit", "onChange"]] = function(_evt, _eid, comp) {
      inventoryItemsMergeEnabled.set(comp.itemContainer__uiItemsMergeEnabled)
      inventoryItemsSortingEnabled.set(comp.itemContainer__uiItemsSortingEnabled)
    },
    function onDestroy(_evt, _eid, _comp) {
      inventoryItemsMergeEnabled.set(true)
      inventoryItemsSortingEnabled.set(true)
    }
  },
  {
    comps_rq = ["watchedByPlr"],
    comps_no = ["player_base_not_ecs_inventory"],
    comps_track = [
      ["itemContainer__uiItemsMergeEnabled", ecs.TYPE_BOOL, true],
      ["itemContainer__uiItemsSortingEnabled", ecs.TYPE_BOOL, true]
    ]
  }
)

return {
  inventoryItems
  backpackItems
  safepackItems
  stashItems
  inventoryItemsMergeEnabled
  inventoryItemsSortingEnabled
  updateEidInventoryContainer
}
