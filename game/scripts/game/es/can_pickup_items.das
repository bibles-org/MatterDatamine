require ecs

[es(track=(isInVehicle, locked__pickupItemsLockedByAffect, isAlive, isDowned))]
def can_pickup_items_conditions(evt : Event;
                                var human__canPickupItems : bool&;
                                isInVehicle : bool = false;
                                locked__pickupItemsLockedByAffect : bool = false;
                                isAlive : bool = true;
                                isDowned : bool = false)
  human__canPickupItems = (!isInVehicle &&
                              !locked__pickupItemsLockedByAffect &&
                              isAlive &&
                              !isDowned)
