require ecs
require game.events.events_active_matter
require game.es.objectives.objective_common


[es(tag=server)]
def objective_win_rounds_on_round_finished(evt : EventNexusRoundModeRoundFinished)
  query() <| $ [es(REQUIRE=(objective_win_rounds, objective_active))] (eid aka objective_eid : EntityId;
                                                                       objective__playerEid : EntityId)
    query(objective__playerEid) <| $ [es] (team : int)
      if evt.winnerTeam == team
        do_progress_for_objective(objective_eid)
