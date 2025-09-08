require ecs
require ecs.common
require game.events.inventory_events
require game.es.inventory_item_common
require game.es.inventory_checks_common
require game.es.ecs_common
require game.es.boxed_item_common


[es(tag=server, on_appear, track=itemContainer)]
def refill_boxed_item_in_inventory_on_container_appear(evt : Event; itemContainer : EidList)
  merge_boxed_items_in_container(itemContainer)


[es(tag=server, on_appear, track=item__currentBoxedItemCount)]
def recalc_boxed_item_weight_and_volume(evt : Event;
                                        item__countPerStack : int;
                                        item__currentBoxedItemCount : int;
                                        item__weightPerStack : float;
                                        item__volumePerStack : float;
                                        var item__weight : float&;
                                        var item__volume : float&)
  let curRelativeValue = float(item__currentBoxedItemCount) / float(item__countPerStack)
  item__weight = floor(item__weightPerStack * curRelativeValue * 10.0) / 10.0 // round to first decimal
  item__volume = float(calc_stacked_item_volume(item__countPerStack, item__currentBoxedItemCount, item__volumePerStack)) / 10.0


[es(track=(item__currentBoxedItemCount, item__containerOwnerEid),
    REQUIRE=(boxedItem, item__currentBoxedItemCount, item__containerOwnerEid))]
def end_boxed_item_split(evt : Event;
                         var boxed_item__actionsBlock : bool&)
  boxed_item__actionsBlock = false


[es(track=(equipmentAttachable__slotName, slot_attach__attachedTo),
    REQUIRE=(equipmentAttachable__slotName, boxedItem, slot_attach__attachedTo))]
def end_boxed_item_split_on_slot_change(evt : Event;
                                        var boxed_item__actionsBlock : bool&)
  boxed_item__actionsBlock = false


[es(tag=server, track=(boxed_item__next, item__currentBoxedItemCount), on_appear)]
def boxed_item_in_advance_create(evt : Event;
                                 item__humanOwnerEid : EntityId;
                                 item__currentBoxedItemCount : int;
                                 item_holder__boxedItemTemplate : das_string const?;
                                 boxed_item__template : das_string const?;
                                 boxed_item_in_advance_exclude_last : Tag const?;
                                 var boxed_item__next : EntityId&)
  if boxed_item__next != INVALID_ENTITY_ID || item__currentBoxedItemCount < 1 || (item__currentBoxedItemCount == 1 && boxed_item_in_advance_exclude_last != null)
    return
  let itemTemplate = item_holder__boxedItemTemplate != null ? string(*item_holder__boxedItemTemplate) : string(*boxed_item__template)
  boxed_item__next = createEntity(itemTemplate) <| $(var init)
    init |> set("item__humanOwnerEid", item__humanOwnerEid)
    init |> set("item__currentBoxedItemCount", 1)


[es(tag=server, on_disappear)]
def boxed_item_in_advance_destroy(evt : Event;
                                  boxed_item__next : EntityId)
  if boxed_item__next != INVALID_ENTITY_ID
    return
  destroyEntity(boxed_item__next)


[es(tag=server, track=item__humanOwnerEid)]
def boxed_item_in_advance_change_owner(evt : Event;
                                       item__humanOwnerEid aka box_item__humanOwnerEid : EntityId;
                                       boxed_item__next : EntityId)
  query(boxed_item__next) <| $ [es] (var item__humanOwnerEid : EntityId&)
    item__humanOwnerEid = box_item__humanOwnerEid
