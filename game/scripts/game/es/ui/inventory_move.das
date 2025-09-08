require ecs


[es(tag=server, track=isDowned)]
def lock_move_items_in_inventory(evt : Event;
                                 isDowned : bool;
                                 var human_inventory__canModifyInventory : bool&)
  human_inventory__canModifyInventory = !isDowned