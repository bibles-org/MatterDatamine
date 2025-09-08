require ecs
require game.events.events_active_matter
require active_matter.game.es.objectives.objective_common


[es(tag=server)]
def objective_activate_corrupted_workbench(evt : EventCorruptedWorkbenchCleaned;
                                           possessedByPlr : EntityId)
  for_each_player_objective(possessedByPlr) <| $ [es] (objective_eid : EntityId)
    if objective_eid |> has("objective_activate_corrupted_workbench")
      complete_progress_for_objective(objective_eid)
