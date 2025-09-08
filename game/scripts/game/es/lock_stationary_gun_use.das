require ecs

[es(track=(human_inventory__entityToUse, locked__stationaryGunUseLockedByAffect))]
def lock_stationary_gun_use(evt : Event;
                            var human_use_object__lockStationaryGunUse : bool&;
                            human_inventory__entityToUse : EntityId = INVALID_ENTITY_ID;
                            locked__stationaryGunUseLockedByAffect : bool = false)
  let lockedByItemUse = human_inventory__entityToUse != INVALID_ENTITY_ID
  human_use_object__lockStationaryGunUse = lockedByItemUse || locked__stationaryGunUseLockedByAffect
