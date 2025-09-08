import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let { item_comps, getItemInfo } = require("%ui/hud/state/item_info.nut")
let {is_move_mod_from_weapon } = require("das.inventory")

let moveModAroundInfo = Watched({})

ecs.register_es("weapon_mod_move_ui_es",
  {
    onInit = function(eid, comp) {
      moveModAroundInfo.set({})

      if (comp.weapon_mod_move__inventoryEid == ecs.INVALID_ENTITY_ID) {
        let itemInfo = getItemInfo(eid, comp)
        itemInfo.isUsable = false
        itemInfo.canDrop = false
        itemInfo.isDelayedMoveMod = true
        itemInfo.inactiveItem = is_move_mod_from_weapon(comp.fake_weapon_mod__realModEid)
        itemInfo.stacks = false
        moveModAroundInfo.set(itemInfo)
      }
    }
    onDestroy = function(eid, comp) {
      if (comp.weapon_mod_move__inventoryEid == ecs.INVALID_ENTITY_ID && moveModAroundInfo.get()?.eid == eid)
        moveModAroundInfo.set({})
    }
  },
  {
    comps_rq = ["watchedPlayerItem", "weaponMod"]
    comps_ro = [["weapon_mod_move__inventoryEid", ecs.TYPE_EID]].extend(item_comps)
  }
)

watchedHeroEid.subscribe(function(_) {
  moveModAroundInfo.set({})
})

return {
  moveModAroundInfo
}
