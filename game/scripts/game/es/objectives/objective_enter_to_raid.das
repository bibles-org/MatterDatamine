require ecs
require game.es.objectives.objective_common


[es(tag=server, on_appear, REQUIRE=(objectiveEnterToRaid, objective_active))]
def objective_enter_to_raid(evt : Event;
                            eid aka objective_eid : EntityId)
  do_progress_for_objective(objective_eid)