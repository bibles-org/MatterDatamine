require ecs
require DngNet
require game.events.events_active_matter
require game.es.objectives.objective_common


[es(tag=server, REQUIRE=monster_hunter, on_appear, track=possessedByPlr)]
def objective_activate_by_monster_hunter(evt : Event;
                                         possessedByPlr : EntityId)
  for_each_player_objective(possessedByPlr) <| $(objective_eid : EntityId)
    query(objective_eid) <| $ [es(REQUIRE=activate_objective_by_player_tag, REQUIRE_NOT=objective_active)] (objective_activate__playerTag : string)
      if objective_activate__playerTag == "monster_hunter"
        remote_add_sub_template(objective_eid, "objective_active")


[es(tag=server, REQUIRE=monster_hunter, on_disappear, on_event=EventEntityDied)]
def objective_deactivate_by_monster_hunter(evt : Event;
                                           possessedByPlr : EntityId)
  for_each_player_objective(possessedByPlr) <| $(objective_eid : EntityId)
    query(objective_eid) <| $ [es(REQUIRE=(activate_objective_by_player_tag, objective_active))] (objective_activate__playerTag : string;
                                                                                                  objective__requireExtraction : bool;
                                                                                                  objective__isCompleted : bool;
                                                                                                  objective__requireFullCompleteInSession : bool)
      if objective_activate__playerTag != "monster_hunter"
        return
      if (objective__requireFullCompleteInSession && !objective__isCompleted) || objective__requireExtraction
        reset_progress_for_objective(objective_eid)
      remote_remove_sub_template(objective_eid, "objective_active")
