require ecs
require game.utils.net_utils
require game.events.events_active_matter
require DngNet
require game.events.events_active_matter


[es(tag=server)]
def change_active_matter_balance_es(evt : CmdChangeActiveMatterBalance;
                                    possessedByPlr : EntityId;
                                    var am_storage__value : int&;
                                    am_storage__maxValue : int)
  if evt.change == 0
    return
  am_storage__value += evt.change
  am_storage__value = min(am_storage__value, am_storage__maxValue)

  let hintKey = evt.change > 0 ? "hint/active_matter_earned/{evt.reason}" : "hint/active_matter_spent/{evt.reason}"

  send_net_event(possessedByPlr,
    EventChangeActiveMatterBalanceHint(hint = hintKey, change = evt.change),
    possessed_and_spectated_player(possessedByPlr))
