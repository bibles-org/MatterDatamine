require ecs
require game.es.notes_common


[es(tag=server, track=player__loadoutRecieved)]
def init_player_notes(evt : Event;
                      eid : EntityId;
                      player__loadoutRecieved : bool)
  if !player__loadoutRecieved
    return
  refill_player_notes(eid)


[es(tag=server, on_event=CmdOpenSwarmNote)]
def open_player_note(evt : Event; eid aka player_eid : EntityId)
  open_note_for_player(player_eid, "note_swarm")