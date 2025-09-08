module notes_common shared

require ecs
require strings
require game.es.unlocks_common
require net
require DagorSystem
require game.utils.net_utils
require game.events.events_active_matter

let
  NOTES_UNLOCK_PREFIX = "note_"

def update_player_notes(player : EntityId)
  query(player) <| $ [es] (player__unlocks : StringList;
                           player__newUnlocks : StringList;
                           var active_matter_player__unlockedNotes : StringList)
    for newUnlock in player__newUnlocks
      if !has_value(player__unlocks, newUnlock)
        let unlockString = string(newUnlock)
        if starts_with(unlockString, NOTES_UNLOCK_PREFIX) && !has_value(active_matter_player__unlockedNotes, unlockString)
          push(active_matter_player__unlockedNotes, unlockString)


def refill_player_notes(player : EntityId)
  query(player) <| $ [es] (player__unlocks : StringList;
                           var active_matter_player__unlockedNotes : StringList)
    clear(active_matter_player__unlockedNotes)

    for unlock in player__unlocks
      let unlockString = string(unlock)
      if starts_with(unlockString, NOTES_UNLOCK_PREFIX)
        push(active_matter_player__unlockedNotes, unlockString)
    update_player_notes(player)


def open_note_for_player(player : EntityId; note_id : string)
  var alreadyUnlocked = false
  query(player) <| $ [es] (active_matter_player__unlockedNotes : StringList)
    alreadyUnlocked = has_value(active_matter_player__unlockedNotes, note_id)

  if alreadyUnlocked
    return false

  if !(note_id |> starts_with(NOTES_UNLOCK_PREFIX))
    logerr("Trying to add note unlock not started with 'note_'.")
    return false

  if open_unlock_for_player(player, note_id)
    update_player_notes(player)
    send_net_event(player, EventUnlockAppear(unlockName = note_id), target_entity_conn(player))
  return true
