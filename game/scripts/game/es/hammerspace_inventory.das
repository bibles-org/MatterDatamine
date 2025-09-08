require ecs
require ecs.safe


[es(tag=server, on_appear)]
def hammerspace_inventory_owner_appear(evt : Event;
                                       hammerspace_inventory_owner__inventoryTemplate : string;
                                       var hammerspace_inventory_owner__inventoryEid : EntityId&)
  hammerspace_inventory_owner__inventoryEid = createEntity(hammerspace_inventory_owner__inventoryTemplate)


[es(tag=server, on_disappear)]
def hammerspace_inventory_owner_disappear(evt : Event;
                                          var hammerspace_inventory_owner__inventoryEid : EntityId&)
  destroyEntity(hammerspace_inventory_owner__inventoryEid)
  hammerspace_inventory_owner__inventoryEid = INVALID_ENTITY_ID