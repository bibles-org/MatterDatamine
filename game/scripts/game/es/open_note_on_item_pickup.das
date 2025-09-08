require ecs
require game.es.notes_common
require game.es.level_common

[es(tag=server, track=item__humanOwnerEid)]
def unlock_note_on_item_pickup(evt : Event;
                               item__humanOwnerEid : EntityId;
                               item__unlockNoteOnPickup : string)
  if !is_player_session()
    return
  query(item__humanOwnerEid) <| $ [es] (possessedByPlr : EntityId)
    open_note_for_player(possessedByPlr, item__unlockNoteOnPickup)
