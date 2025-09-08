import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *


let isInMonsterState = Watched(false)
let isMonsterInventoryEnabled = Watched(false)
let isMonsterWeaponsEnabled = Watched(false)


ecs.register_es("track_hero_monster_state",
{
  onInit = function(_evt, _eid, comp) {
    isInMonsterState.set(comp.player_controlled_monster != null)
    isMonsterInventoryEnabled.set(comp.player_controlled_monster__inventoryEnabled)
    isMonsterWeaponsEnabled.set(comp.player_controlled_monster__weaponsEnabled)
  }
  
  
},
{
  comps_rq = [ "watchedByPlr" ]
  comps_ro = [
    ["player_controlled_monster", ecs.TYPE_TAG, null],
    ["player_controlled_monster__inventoryEnabled", ecs.TYPE_BOOL, false],
    ["player_controlled_monster__weaponsEnabled", ecs.TYPE_BOOL, false]
  ]
})

return {
  isInMonsterState
  isMonsterInventoryEnabled
  isMonsterWeaponsEnabled
}