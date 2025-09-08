import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let {HERO_ITEM_CONTAINER, EXTERNAL_ITEM_CONTAINER,
     BACKPACK0, STASH, SAFEPACK} = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let {get_controlled_hero} = require("%dngscripts/common_queries.nut")
let {externalInventoryEid} = require("%ui/hud/state/hero_external_inventory_state.nut")
let {backpackEid, safepackEid} = require("%ui/hud/state/hero_extra_inventories_state.nut")
let {stashEid} = require("%ui/hud/state/stash_items_es.nut")

function getInventoryEidByListType(list_type) {
  if (list_type == HERO_ITEM_CONTAINER)
    return get_controlled_hero()
  else if (list_type == EXTERNAL_ITEM_CONTAINER)
    return externalInventoryEid.value
  else if (list_type == BACKPACK0)
    return backpackEid.value
  else if (list_type == STASH)
    return stashEid.value
  else if (list_type == SAFEPACK)
    return safepackEid.value
  return ecs.INVALID_ENTITY_ID
}

return {
  getInventoryEidByListType
}
