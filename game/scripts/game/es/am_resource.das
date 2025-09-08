require ecs
require app
require ecs.safe
require ecs.common
require math.random
require inventory
require game.events.events
require game.events.events_active_matter


def find_item_to_syphon(itemContainer : EidList;
                        am_syphon__period : float;
                        var am_syphon__extractionSource : EntityId&;
                        var am_syphon__updateAt : float&)
  am_syphon__extractionSource = INVALID_ENTITY_ID
  for itemEid in itemContainer
    query(itemEid) <| $ [es] (am_storage__value aka item_am_storage__value : int&)
      if item_am_storage__value > 0
        am_syphon__extractionSource = itemEid
    if am_syphon__extractionSource != INVALID_ENTITY_ID
      am_syphon__updateAt = get_sync_time() + am_syphon__period
      break


[es(tag=server, track=itemContainer)]
def track_hero_has_item_to_syphon(evt : Event; itemContainer : EidList;
                                  am_syphon__period : float;
                                  var am_syphon__extractionSource : EntityId&;
                                  var am_syphon__updateAt : float&)
  // try take previous one if still in container, if not - find new one
  if am_syphon__extractionSource == INVALID_ENTITY_ID || !has_value(itemContainer, am_syphon__extractionSource)
    find_item_to_syphon(itemContainer, am_syphon__period, am_syphon__extractionSource, am_syphon__updateAt)


[es(tag=server, before=change_active_matter_balance_es)]
def resume_syphoning_item_on_am_usage(evt : CmdChangeActiveMatterBalance;
                                      am_storage__maxValue : int;
                                      itemContainer : EidList;
                                      am_storage__value : int&;
                                      am_syphon__period : float;
                                      var am_syphon__extractionSource : EntityId&;
                                      var am_syphon__updateAt : float&)
  if (am_storage__value >= am_storage__maxValue && am_storage__value + evt.change < am_storage__maxValue)
    // was full
    find_item_to_syphon(itemContainer, am_syphon__period, am_syphon__extractionSource, am_syphon__updateAt)


[es(tag=server)]
def stop_syphoning_item_on_item_usage(evt : EventOnItemStartUse;
                                      eid aka item_eid : EntityId)
  query(evt.userEid) <| $ [es] (itemContainer : EidList;
                                am_syphon__period : float;
                                var am_syphon__extractionSource : EntityId&;
                                var am_syphon__updateAt : float&)
    if item_eid != am_syphon__extractionSource
      return

    am_syphon__extractionSource = INVALID_ENTITY_ID
    for itemInContainerEid in itemContainer
      if itemInContainerEid == item_eid
        continue
      query(itemInContainerEid) <| $ [es] (am_storage__value aka item_am_storage__value : int&)
        if item_am_storage__value > 0
          am_syphon__extractionSource = itemInContainerEid
      if am_syphon__extractionSource != INVALID_ENTITY_ID
        am_syphon__updateAt = get_sync_time() + am_syphon__period
        break


[es(tag=server, no_order)]
def extract_am_from_items(act : ParallelUpdateFrameDelayed;
                          am_storage__maxValue : int;
                          itemContainer : EidList;
                          am_syphon__period : float;
                          var am_storage__value aka player_am_storage__value : int&;
                          var am_syphon__extractionSource : EntityId&;
                          var am_syphon__updateAt : float&)
  if am_syphon__extractionSource == INVALID_ENTITY_ID || player_am_storage__value >= am_storage__maxValue
    am_syphon__extractionSource = INVALID_ENTITY_ID
    return
  if am_syphon__updateAt < act.curTime
    am_syphon__updateAt += am_syphon__period
    query(am_syphon__extractionSource) <| $ [es] (var am_storage__value aka item_am_storage__value : int&)
      player_am_storage__value++
      item_am_storage__value--
      if item_am_storage__value == 0
        am_syphon__extractionSource = INVALID_ENTITY_ID
    if am_syphon__extractionSource == INVALID_ENTITY_ID
      // need to find another source
      find_item_to_syphon(itemContainer, am_syphon__period, am_syphon__extractionSource, am_syphon__updateAt)


[es(tag=server, on_appear)]
def init_am_starting_value(evt : Event; am_storage__startingValue : int2; var am_storage__value : int&)
  am_storage__value = rnd_int(am_storage__startingValue)