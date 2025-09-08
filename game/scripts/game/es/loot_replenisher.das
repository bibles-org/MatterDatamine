require ecs
require app
require game.events.inventory_events
require game.events.events_active_matter
require math.base


[es(tag=server, REQUIRE=eid)]
def loot_replenisher_on_pickup(evt : CmdItemPickup)
  query(evt.item) <| $ [es(REQUIRE=loot_rules__replenishLoot)] (transform : float3x4; item__scaleMult = 1.0)
    createEntity(getEntityTemplateName(evt.item)) <| $(var init)
      // apply inverse scale to avoid double scaling
      set(init, "transform", transform * scale_tm(1.0 / item__scaleMult))


[es(tag=server, REQUIRE=transform)]
def loot_replenisher_on_move(evt : EventOnItemPickup)
  query(evt.itemEid) <| $ [es(REQUIRE=loot_rules__replenishLoot)] (transform : float3x4; item__scaleMult = 1.0)
    createEntity(getEntityTemplateName(evt.itemEid)) <| $(var init : ComponentsInitializer)
      // apply inverse scale to avoid double scaling
      set(init, "transform", transform * scale_tm(1.0 / item__scaleMult))


[es(tag=server, REQUIRE=transform)]
def loot_time_replenisher(evt : EventOnItemPickup)
  query(evt.itemEid) <| $ [es] (transform : float3x4; loot_rules__replenishTime : float)
    createEntity("item_to_replenish") <| $(var init : ComponentsInitializer)
      set(init, "transform", transform)
      set(init, "loot_replenisher__template", getEntityTemplateName(evt.itemEid))
      set(init, "loot_replenisher__replenishAtTime", get_sync_time() + loot_rules__replenishTime)

[es(tag=server, no_order)]
def loot_replenish_after_timeout(info : ParallelUpdateFrameDelayed;
                                 eid : EntityId;
                                 loot_replenisher__template : string;
                                 loot_replenisher__replenishAtTime : float;
                                 transform : float3x4)
  if info.curTime < loot_replenisher__replenishAtTime
    return
  createEntity(loot_replenisher__template) <| $(var init : ComponentsInitializer)
    set(init, "transform", transform)
  destroyEntity(eid)

