from "%ui/helpers/remap_nick.nut" import remap_nick

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let getNameQuery = ecs.SqQuery("getNameQuery", {comps_ro = [["name", ecs.TYPE_STRING]], comps_rq=["player"]})
function getName(playereid) {
  if (playereid == ecs.INVALID_ENTITY_ID)
    return null
  let name = getNameQuery.perform(playereid, @(_eid, comp) comp.name)
  if (name!=null)
    return remap_nick(name)
  return null
}
let selectedItem = Watched()

function updateItem(eid, comp) {
  let playerItemOwner = comp["playerItemOwner"]
  selectedItem.set({
    maxDistance = comp["hud_marker__max_distance"]
    showOnlyWhenSelected = comp["hud_marker__showOnlyWhenSelected"]
    text = comp["item__name"]
    count = comp["item__count"]
    ammoCount = comp["boxedItem"] != null ? comp["item__currentBoxedItemCount"] : null,
    nickname = comp["cortical_vault_inactive__ownerNickname"] ?? getName(playerItemOwner)
    lootType = comp["item__lootType"]
    weapType = comp["item__weapType"]
    volume = comp["item__volume"]
    transform = comp.transform
    eid
    useAltActionPrompt = comp?.item__setCustomUseAltPrompt
    useActionPrompt = comp?.item__setCustomUsePrompt
    rarity = comp.item__rarity
  })
}

ecs.register_es("loot_markers_selected_ui_es",
  {
    onInit = @(eid, comp) updateItem(eid, comp),
    function onDestroy(eid, _){
      if (selectedItem.get()?.eid == eid)
        selectedItem.set(null)
    }
  },
  {
    comps_ro = [
      ["hud_marker__max_distance", ecs.TYPE_FLOAT, 10.0],
      ["hud_marker__showOnlyWhenSelected", ecs.TYPE_BOOL, false],
      ["playerItemOwner", ecs.TYPE_EID, ecs.INVALID_ENTITY_ID],
      ["item__name", ecs.TYPE_STRING],
      ["item__count", ecs.TYPE_INT, 0],
      ["item__lootType", ecs.TYPE_STRING, "item"],
      ["item__weapType", ecs.TYPE_STRING, null],
      ["item__volume", ecs.TYPE_INT, 0],
      ["transform", ecs.TYPE_MATRIX, null],
      ["item__currentBoxedItemCount", ecs.TYPE_INT, null],
      ["boxedItem", ecs.TYPE_TAG, null],
      ["usable_backpack", ecs.TYPE_TAG, null],
      ["item__setCustomUseAltPrompt", ecs.TYPE_STRING, null],
      ["item__setCustomUsePrompt", ecs.TYPE_STRING, null],
      ["cortical_vault_inactive__ownerNickname", ecs.TYPE_STRING, null],
      ["item__rarity", ecs.TYPE_STRING, null]
    ],
    comps_rq = ["ui_visible"]
    comps_no = ["item__am"]
  }
)

let loot_markers = Computed(function() {
  let item = selectedItem.get()
  return item!=null ? {[item.eid] = item} : {}
})

return {
  loot_markers
}