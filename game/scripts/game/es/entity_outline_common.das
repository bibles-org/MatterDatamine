module entity_outline_common shared

require ecs
require app
require DagorMath

def try_enable_entity_outline(eid : EntityId; color : E3DCOLOR; duration : float)
  let endTime = get_sync_time() + duration
  query(eid) <| $ [es] (var outline__color : E3DCOLOR&; var outline__enabled : bool&)
    outline__color = color
    if !outline__enabled
      outline__enabled = true
      create_timer(eid, endTime)
    else
      let success = find_query() <| $ [es] (var game_effect_outline__disableAt : float&; game_effect__attachedTo : EntityId)
        if game_effect__attachedTo == eid
          game_effect_outline__disableAt = max(game_effect_outline__disableAt, endTime)
          return true
        return false
      if !success
        create_timer(eid, endTime)


def private create_timer(eid : EntityId; end_time : float)
  createEntity("game_effect_outline") <| $(init)
    set(init, "game_effect__attachedTo", eid)
    set(init, "game_effect_outline__disableAt", end_time)