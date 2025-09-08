require ecs
require game.es.player_common
require game.es.client.spectator_common
require game.events.events_game


[es(tag=input)]
def change_spectator_target_after_death(evt : EventAnyEntityDied;
                                        eid : EntityId;
                                        spectator__teamId : int;
                                        var spectator__target : EntityId&)
  if spectator__target == evt.victim
    set_spectated(eid, spectator__target, find_next_spec_target(spectator__teamId, spectator__target, +1))


[es(tag=gameClient, on_disappear, REQUIRE=watchedByPlr)]
def change_spectator_on_dissappear(evt : Event;
                                   eid aka human_eid : EntityId)
  query() <| $ [es(REQUIRE=spectator)] (eid aka camera_eid : EntityId;
                                        spectator__teamId : int;
                                        var spectator__target : EntityId&)
    if spectator__target == human_eid
      set_spectated(camera_eid, spectator__target, find_next_spec_target(spectator__teamId, spectator__target, +1))
