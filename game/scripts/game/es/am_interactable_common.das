module am_interactable_common shared
require ecs

def end_interaction(var interactable__invoiceList : EidList;
                    var interactable__heroEid : EntityId&;
                    var human_use_object__currentInteractable : EntityId&)
  human_use_object__currentInteractable = INVALID_ENTITY_ID
  interactable__heroEid = INVALID_ENTITY_ID
  for action in interactable__invoiceList
    destroyEntity(action)
  clear(interactable__invoiceList)