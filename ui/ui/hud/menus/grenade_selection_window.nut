from "dasevents" import CmdHideUiMenu, TryUseItem
from "%ui/components/mkQuickMenu.nut" import mkQMenu
from "string" import startswith
from "%ui/components/itemIconComponent.nut" import itemIconNoBorder

from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs


let { equipmentModSlots } = require("%ui/hud/state/equipment.nut")
let { inventoryItems } = require("%ui/hud/state/inventory_items_es.nut")
let { controlledHeroEid } = require("%ui/hud/state/controlled_hero.nut")

const GRENADE_SELECTION_ID = "grenadeSelectionWnd"

let closeGrenadeUi = @() ecs.g_entity_mgr.broadcastEvent(CmdHideUiMenu({ menuName = GRENADE_SELECTION_ID }))

function getGrenadeItems() {
  let grenadesInPockets = (equipmentModSlots.get() ?? {})
    .map(@(mods) mods.filter(@(_v, k) startswith(k, "equipment_mod_pocket")))
    .reduce(function(res, p) {
      foreach (item in p)
        if (item?.itemTemplate != null
          && item?.itemType == "grenade"
          && res.findvalue(@(v) v.itemTemplate == item.itemTemplate) == null
        )
          res.append(item)
      return res
    }, [])

  let grenadesInPouches = inventoryItems.get().reduce(function(res, item) {
    if (item?.itemTemplate != null
      && item?.itemType == "grenade"
      && grenadesInPockets.findvalue(@(v) v.itemTemplate == item.itemTemplate) == null
      && res.findvalue(@(v) v.itemTemplate == item.itemTemplate) == null
    )
      res.append(item)
    return res
  }, [])

  return [].extend(grenadesInPockets, grenadesInPouches)
    .map(@(v) {
      action = @() ecs.g_entity_mgr.sendEvent(v.eid, TryUseItem({userEid = controlledHeroEid.get(), targetEid=controlledHeroEid.get()}))
      text = loc(v?.itemName)
      icon = itemIconNoBorder(v?.itemTemplate, {
        width = hdpx(28)
        height = hdpx(28)
        shading = "full"
      })
    })
}

let grenadeUi = mkQMenu(getGrenadeItems, closeGrenadeUi, GRENADE_SELECTION_ID,
  loc("controls/Human.ChooseGrenade"), loc("controls/Human.ChooseGrenade/empty"))

return {
  GRENADE_SELECTION_ID
  grenadeUi
}
