require ecs
require net
require game.utils.net_utils
require game.es.unlocks_common
require game.events.events_active_matter


[es(tag=server, track=item__humanOwnerEid)]
def unlocks_on_pickup(evt : Event;
                      item__humanOwnerEid : EntityId;
                      pickup_unlock__name : string)
  query(item__humanOwnerEid) <| $ [es] (possessedByPlr : EntityId)
    if open_unlock_for_player(possessedByPlr, pickup_unlock__name)
      send_net_event(possessedByPlr, EventUnlockAppear(unlockName = pickup_unlock__name), target_entity_conn(possessedByPlr))
