require app
require ecs
require ecs.safe
require game.events.inventory_events
require game.events.events_active_matter
require game.events.inventory_events
require game.events.events
require DngNet
require game.es.level_common



// TODO: global rework device mechanics
[es(tag=server)]
def on_device_use(evt : EventOnLootItemUsed;
                  device_item__ability : Object;
                  device_item__startCooldownOnEquip : bool = false)
  query(evt.target) <| $ [es] (var hero_ability__abilities : Array;
                               var hero_ability__abilitiesCooldown : Object;
                               var hero_ability__abilitiesNextUseTime : Object)
    // mark device abilities to distinguish them from hero abilities
    let name = get_string(device_item__ability, "name", "")
    var idx = -1
    using() <| $(var newAbilities : Array)
      for it in hero_ability__abilities
        let ability = get_ecs_object(it)
        // remove old device ability
        if get_bool(ability, "device_ability") ?? false
          continue
        newAbilities.push(it)
      using() <| $(var itemAbility : Object)
        itemAbility := device_item__ability
        itemAbility |> set("device_ability", true)
        idx = length(newAbilities)
        newAbilities.push(itemAbility)
      hero_ability__abilities := newAbilities
    if device_item__startCooldownOnEquip
      let abilityCooldown = get_float(device_item__ability, "cooldown") ?? 0.0
      let curTime = get_sync_time()
      hero_ability__abilitiesCooldown |> set(name, abilityCooldown)
      set(hero_ability__abilitiesNextUseTime, name, curTime + abilityCooldown)
    send_net_event(evt.target, RqUseAbility(idx = idx))


[es(tag=server, REQUIRE=eid)]
def destroy_item_device_after_use(evt : EventOnDeviceUsed)
  if is_player_base()
    return
  query(evt.playerEid) <| $ [es] (possessed : EntityId)
    query(possessed) <| $ [es] (human_inventory__lastUsedItemDevice : EntityId)
      if !has(human_inventory__lastUsedItemDevice, "item_device__notConsumedWhenUsed")
        destroyEntity(human_inventory__lastUsedItemDevice)