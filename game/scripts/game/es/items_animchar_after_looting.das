require ecs
require strings
require game.events.inventory_events


[es(REQUIRE=eid)]
def set_item_animchar_after_looting(evt : EventOnItemPickup)
  query(evt.itemEid) <| $ [es] (item__animcharAfterLooting : string; var animchar__res : das_string&)
    if empty(item__animcharAfterLooting)
      return
    animchar__res := item__animcharAfterLooting