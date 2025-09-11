from "%dngscripts/globalState.nut" import nestWatched
from "base64" import encodeString
from "%ui/mainMenu/ribbons_colors_state.nut" import indexToColor
from "das.ribbons_color" import get_primary_color_of_hero, get_secondary_color_of_hero
from "%ui/mainMenu/clonesMenu/clonesMenuCommon.nut" import getChronogeneItemByUniqueId
from "json" import object_to_json_string

from "%ui/ui_library.nut" import *

let { currentChronogenes } = require("%ui/mainMenu/clonesMenu/cloneMenuState.nut")
let { playerCurrentLevel } = require("%ui/hud/menus/notes/player_progression.nut")
let { squadWeaponsList } = require("%ui/hud/state/hero_weapons.nut")
let { attachedEquipment } = require("%ui/hud/state/equipment.nut")
let { teamColorIdxs, numOfflineRaidsAvailable } = require("%ui/profile/profileState.nut")

let playersData = Computed(function() {
  return {
    ribbons = teamColorIdxs.get()
    hasIsolatedRaidTickets = numOfflineRaidsAvailable.get() > 0
    attachedEquipment = attachedEquipment.get().values()
    mainAlter = getChronogeneItemByUniqueId(currentChronogenes.get()?.primaryChronogenes[0])?.itemTemplate
    level = playerCurrentLevel.get()
    weaponsList = squadWeaponsList.get()
    weaponTemplates = squadWeaponsList.get().map(@(w) w?.itemTemplate ?? "")
    weaponMods = squadWeaponsList.get().map(function(w) {
      let mods = w?.mods ?? {}
      let res = {}
      foreach (slot, mod in mods) {
        res[slot] <- mod?.itemTemplate
      }
      return res
    } )
    selectedWeapSlot = squadWeaponsList.get().findindex(@(w) w?.isCurrent ?? false)
  }
})

return { playersData }