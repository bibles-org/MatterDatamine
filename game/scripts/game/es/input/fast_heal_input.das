require ecs
require DngNet
require game.events.input_events
require game.events.events_game
require game.events.events_active_matter
require game.es.damage_systems.damage_model_healing_common


[es(tag=input)]
def fast_heal_input_triggered_es(evt : EventDaInputActionTriggered;
                                 eid : EntityId;
                                 human_input__fastHeal : int;
                                 input__enabled : bool;
                                 isAlive = true;
                                 burning__isBurning = false)
  if !input__enabled || burning__isBurning || !isAlive
    return
  let action = int(evt.action)
  if action == human_input__fastHeal
    let healItem = get_most_needed_heal_item(eid)
    sendEvent(healItem, TryUseItem(userEid = eid))
