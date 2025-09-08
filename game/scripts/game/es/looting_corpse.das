require ecs
require game.events.events


[es(tag=server, on_appear, REQUIRE=lootingCorpseContainerInvoice)]
def init_looting_corpse_container_invoice(evt : Event;
                                          interactable_invoice__hero, interactable_invoice__parentInteractableEid : EntityId)
  query(interactable_invoice__parentInteractableEid) <| $ [es] (ragdoll_phys_obj__attachedTo : EntityId)
    sendEvent(ragdoll_phys_obj__attachedTo, CmdUse(requesterEid = interactable_invoice__hero))

