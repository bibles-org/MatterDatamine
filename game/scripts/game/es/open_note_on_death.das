require ecs
require strings
require game.events.events
require game.es.notes_common
require game.events.events_game


[es(tag=server, before=trigger_firefly_on_death)]
def unlock_note_on_death(evt : EventEntityDied;
                         possessedByPlr aka victim_possessedByPlr = INVALID_ENTITY_ID;
                         death_note__name = "")
  var noteType := death_note__name
  query(evt.offender) <| $ [es] (death_note__name : string)
    noteType := death_note__name

  if !empty(noteType)
    query(evt.offender) <| $ [es] (possessedByPlr : EntityId)
      open_note_for_player(possessedByPlr, noteType)
    open_note_for_player(victim_possessedByPlr, noteType)
