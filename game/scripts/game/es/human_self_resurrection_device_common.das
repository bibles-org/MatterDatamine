module human_self_resurrection_device_common shared
require ecs


def find_player_ressurection_device(player_eid : EntityId)
  var res = INVALID_ENTITY_ID
  find_query() <| $ [es(REQUIRE=self_resurrection_device)] (eid : EntityId; playerOwnerEid : EntityId)
    if playerOwnerEid == player_eid
      res = eid
      return true
    return false
  return res
