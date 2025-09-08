require ecs
require soundEvent
require strings


[es(tag=sound, track=openable_ri__isOpened)]
def openable_ri_sound(evt : Event;
                      openable_ri__isOpened : bool;
                      openable_ri_sound__folder : string;
                      openable_ri_sound__path : string;
                      openable_ri_sound__openName : string;
                      openable_ri_sound__closeName : string;
                      transform : float3x4)
  if !empty(openable_ri_sound__path)
    let path = "{openable_ri_sound__folder}/{openable_ri_sound__path}/{openable_ri__isOpened ? openable_ri_sound__openName : openable_ri_sound__closeName}"
    oneshot(path, transform[3])


[es(tag=sound, track=external_inventory_interactor__inventoryEid)]
def external_inventory_interactor_sound(evt : Event;
                                        external_inventory_interactor__inventoryEid : EntityId)

  query(external_inventory_interactor__inventoryEid) <| $ [es] (external_inventory_interactor_sound__path : string;
                                                                transform : float3x4)
    oneshot(external_inventory_interactor_sound__path, transform[3])
