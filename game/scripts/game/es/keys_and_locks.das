require ecs
require math.random
require game.es.level_common
require game.events.events
require game.es.keys_and_locks_common
require game.events.events_active_matter


[es(tag=server, on_appear, REQUIRE=doorsGenerationDone, after=double_doors_es)]
def mark_doors_locked(evt : Event)
  query() <| $ [es] (transform : float3x4;
                     locked_door_marker__template : string;
                     locked_door_marker__keyTags : StringList)
    try_mark_doors_closed(transform, locked_door_marker__template, locked_door_marker__keyTags)


[es(tag=server, on_appear, REQUIRE=locked_door_marker__adhock)]
def adhock_mark_doors_locked(evt : Event;
                             transform : float3x4;
                             locked_door_marker__template : string;
                             locked_door_marker__keyTags : StringList)
  try_mark_doors_closed(transform, locked_door_marker__template, locked_door_marker__keyTags)


[es(before=door_operations)]
def lock_unlock_es(evt : CmdUse;
                   var locked__isLocked : bool&;
                   locked__keyTags : StringList)
  if locked__isLocked == false
    return

  query(evt.requesterEid) <| $ [es] (inventories_owner__inventoryEids : EidList)
    for inventoryEid in inventories_owner__inventoryEids
      if locked__isLocked == false // opened from previous container iteration
        return
      query(inventoryEid) <| $ [es] (itemContainer : EidList)
        for item in itemContainer
          if locked__isLocked == false // opened from previous item container iteration
            return
          query(item) <| $ [es] (item__name : string; key__tags : StringList; var item__amount : int?)
            if have_same_tag(locked__keyTags, key__tags)
              if item__amount != null
                *item__amount -= 1
              locked__isLocked = false
              using() <| $(var obj : Object)
                obj |> set("name", item__name)
                sendEvent(evt.requesterEid, CmdHeroLogExEventLocal(event = "key_used", key = "key_used", data = ecs_addr(obj)))


[es(tag=server, track=item__amount, REQUIRE=key__tags)]
def destroy_key_on_no_charges_left(evt : Event; eid : EntityId; item__amount : int)
  if item__amount <= 0
    destroyEntity(eid)


[es(tag=server, on_appear)]
def key_init_charges(evt : Event;
                     key__initCharges : int2;
                     var item__amount : int&)
  if is_player_base()
    return
  item__amount = rnd_int(key__initCharges)
