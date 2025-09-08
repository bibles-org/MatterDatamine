module unlocks_common shared

require ecs


def open_unlock_for_player(player : EntityId; unlock : string) : bool
  var result = false
  query(player) <| $ [es] (var player__newUnlocks : StringList)
    if !has_value(player__newUnlocks, unlock)
      push(player__newUnlocks, unlock)
      result = true
  return result
