require ecs
require game.events.events_active_matter
require game.events.events_game
require active_matter.game.es.objectives.objective_common
require game.events.events_game


def update_am_gather_objectives(player_eid : EntityId; change : int)
  var remainingAmCount = change
  if remainingAmCount > 0
    for_each_player_objective(player_eid) <| $(var objective_eid : EntityId)
      if remainingAmCount == 0
        return
      if objective_eid |> has("objectiveGatherAm")
        remainingAmCount -= do_progress_for_objective(objective_eid, remainingAmCount)


def reset_all_am_gather_objectives(player_eid)
  for_each_player_objective(player_eid) <| $(var objective_eid : EntityId)
    if has(objective_eid, "objectiveGatherAm")
      reset_progress_for_objective(objective_eid)


[es(tag=server)]
def objective_gather_am_progress_on_am_looted(evt : EventAmLooted;
                                              eid : EntityId)
  update_am_gather_objectives(eid, evt.amount)


[es(tag=server, after=change_active_matter_balance_es)]
def objective_gather_am_progress_on_balance_change(evt : CmdChangeActiveMatterBalance;
                                                   possessedByPlr : EntityId;
                                                   am_storage__value : int)
  if evt.change > 0
    update_am_gather_objectives(possessedByPlr, evt.change)
  else
    reset_all_am_gather_objectives(possessedByPlr)
    update_am_gather_objectives(possessedByPlr, am_storage__value)


[es(tag=server)]
def objective_gather_am_reset_progress_on_death(evt : EventEntityDied;
                                                possessedByPlr : EntityId)
  reset_all_am_gather_objectives(possessedByPlr)
