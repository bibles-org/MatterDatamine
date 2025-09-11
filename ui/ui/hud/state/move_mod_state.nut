from "%ui/hud/state/item_info.nut" import getItemInfo
from "das.inventory" import is_move_mod_from_weapon
import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")
let { item_comps } = require("%ui/hud/state/item_info.nut")

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

ecs.register_es("weapon_mod_holder_loading_es",
  {
    onInit = function(eid, comp) {
      moveModAroundInfo.set({})

      if (comp.weapon_mod_move__fakeModEid == ecs.INVALID_ENTITY_ID) {
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
      if (comp.weapon_mod_move__fakeModEid == ecs.INVALID_ENTITY_ID && moveModAroundInfo.get()?.eid == eid)
        moveModAroundInfo.set({})
    }
  },
  {
    comps_rq = ["watchedPlayerItem", "item_holder_in_weapon_load"]
    comps_no = ["weapon_mod_move__inventoryEid"]
    comps_ro = [["weapon_mod_move__fakeModEid", ecs.TYPE_EID]].extend(item_comps)
  }
)

watchedHeroEid.subscribe_with_nasty_disregard_of_frp_update(function(_) {
  moveModAroundInfo.set({})
})

return {
  moveModAroundInfo
}
