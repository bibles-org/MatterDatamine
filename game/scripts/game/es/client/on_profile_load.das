require ecs
require level
require DngNet
require strings
require game.events.player_events


let
  NOTES_UNLOCK_PREFIX = "note_"


[es(tag=gameClient, on_appear, on_event=EventProfileLoaded)]
def spawn_on_profile_loaded(evt : Event; player_profile__isLoaded : bool)
  if !player_profile__isLoaded || !is_level_loaded()
    return
  find_query() <| $ [es] (eid : EntityId; is_local : bool; possessed : EntityId)
    if !is_local
      return false
    if !doesEntityExist(possessed)
      print("[Spawn] spawn_on_profile_loaded - default respawn")
      send_net_event(eid, PlayerRequestSpawnInWorld())
    return true


[es(tag=gameClient, on_appear, track=is_local)]
def spawn_on_player_loaded(evt : Event; is_local : bool; eid, possessed : EntityId)
  if is_local && possessed == INVALID_ENTITY_ID && is_level_loaded()
    find_query() <| $ [es] (player_profile__isLoaded : bool)
      if player_profile__isLoaded
        print("[Spawn] spawn_on_player_loaded - default respawn")
        send_net_event(eid, PlayerRequestSpawnInWorld())
        return true
      return false


[es(tag=gameClient, on_event=EventLevelLoaded)]
def spawn_on_level_loaded(evt : Event; is_local : bool; eid, possessed : EntityId)
  if is_local && possessed == INVALID_ENTITY_ID
    find_query() <| $ [es] (player_profile__isLoaded : bool)
      if player_profile__isLoaded
        print("[Spawn] spawn_on_level_loaded - default respawn")
        send_net_event(eid, PlayerRequestSpawnInWorld())
        return true
      return false


[es(tag=gameClient, on_appear, on_event=EventProfileLoaded)]
def fill_player_unlocks_on_profile_loaded(evt : Event;
                                          player_profile__isLoaded : bool;
                                          player_profile__unlocks : StringList)
  if !player_profile__isLoaded
    return
  find_query() <| $ [es] (is_local : bool;
                          var player__unlocks : StringList)
    if !is_local
      return false
    clear(player__unlocks)
    for unlock in player_profile__unlocks
      push(player__unlocks, unlock)
    return true

[es(tag=gameClient, on_appear, on_event=EventProfileLoaded)]
def fill_notes_on_profile_loaded(evt : Event;
                                 player_profile__isLoaded : bool;
                                 player_profile__unlocks : StringList)
  if !player_profile__isLoaded
    return

  find_query() <| $ [es] (var active_matter_player__unlockedNotes : StringList)
    clear(active_matter_player__unlockedNotes)
    for unlock in player_profile__unlocks
      let unlockString = string(unlock)
      if starts_with(unlockString, NOTES_UNLOCK_PREFIX)
        push(active_matter_player__unlockedNotes, unlockString)
    return true
