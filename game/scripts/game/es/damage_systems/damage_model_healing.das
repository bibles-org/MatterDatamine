require app
require ecs
require DngNet
require DngHuman
require game.utils.net_utils
require game.events.events
require game.events.events_active_matter
require game.es.damage_systems.damage_model_common
require game.es.damage_systems.damage_model_healing_common
require game.es.inventory_checks_common
require game.es.inventory_item_common
require game.es.inventory_common
require game.es.pain_common
require game.es.entity_mods_common
require game.es.human_inventory_postponed_usage_common
require game.es.status_tip_common
require game.es.interrupt_item_use_common


let private PREFIX = "HEAL"


enum CanUseHealResponse
  Approved
  Declined
  UnarmedUsage
  NoUseTime
  NotOwner
  Downed
  HealAlreadyInUse
  NoPartToHeal
  FullHp
  TooFarForUseOnPickup
  NoHealItemsInBoxedItem
  NoHealItems


def heal_use(human_eid : EntityId;
             item_eid : EntityId;
             use_start_time : float;
             use_duration : float;
             progress_bar_duration : float;
             heal_start_delay : float;
             part_index : int;
             server : bool;
             four_step_healing__effectTemplateName : string;
             var human_net_phys : HumanActor&;
             var four_step_healing__effectEid : EntityId&)
  inventory_item_prepare_using(human_eid, item_eid, human_eid, use_start_time, use_duration, progress_bar_duration)
  human_net_phys.phys.currentState |> human_phys_state_set_stoppedSprint(true)
  create_four_step_healing_effect(human_eid, item_eid, four_step_healing__effectTemplateName, use_start_time + heal_start_delay, part_index, server && is_true_net_server(), four_step_healing__effectEid)

  if !server
    send_net_event(human_eid, RequestUseHeal(itemEid = item_eid, partIndex = part_index, atTime = use_start_time))
  sendEvent(item_eid, EventOnItemStartUse(userEid = human_eid, targetEid = human_eid))


def check_heal_can_be_used(human_eid : EntityId;
                           item_eid : EntityId;
                           item_human_owner_eid : EntityId;
                           item_container_owner_eid : EntityId;
                           human_pos : float3;
                           part_index_to_heal : int;
                           use_time : float;
                           human_inventory__pickupRemoveRadius : float;
                           human_damage_model__sumHpAllBodyParts : float;
                           human_damage_model__sumMaxHpAllBodyParts : float;
                           isDowned : bool;
                           item__unarmedUsage : bool;
                           item_heal_revive : Tag const?;
                           item_heal_hot : Tag const?;
                           item__currentBoxedItemCount : int const?)
  if !item__unarmedUsage
    return CanUseHealResponse.UnarmedUsage

  if use_time <= 0.0f
    return CanUseHealResponse.NoUseTime

  if item__currentBoxedItemCount != null && *item__currentBoxedItemCount < 1
    return CanUseHealResponse.NoHealItemsInBoxedItem

  let isRevive = item_heal_revive != null
  let isPosteffect = item_heal_hot != null
  // painkillers and injector could be used directly, because they have lasting effect
  if ((human_damage_model__sumHpAllBodyParts >= human_damage_model__sumMaxHpAllBodyParts)
        && !isRevive && !isPosteffect)
    return CanUseHealResponse.FullHp

  if isDowned // Downed can use only painkiller
    if !isRevive
      return CanUseHealResponse.Downed
    return CanUseHealResponse.Approved

  if part_index_to_heal == -1 && !isRevive && !isPosteffect
    return CanUseHealResponse.NoPartToHeal

  if item_human_owner_eid != human_eid && item_human_owner_eid != INVALID_ENTITY_ID
    return CanUseHealResponse.NotOwner

  if !can_hero_acess_item_relaxed(human_eid, item_eid, item_human_owner_eid, item_container_owner_eid, human_pos, human_inventory__pickupRemoveRadius)
    return CanUseHealResponse.TooFarForUseOnPickup

  return CanUseHealResponse.Approved


def create_four_step_healing_effect(human_eid : EntityId;
                                    item_eid : EntityId;
                                    effect_template_name : string;
                                    heal_at : float;
                                    part_index : int;
                                    server : bool;
                                    var healing_effect_eid : EntityId&)
  let effect_template_name_full = effect_template_name + (server ? "" : "+healing_effect_client")
  healing_effect_eid = createEntity(effect_template_name_full) <| $(init)
    init |> set("game_effect__attachedTo", human_eid)
    init |> set("four_step_healing__item", item_eid)
    init |> set("four_step_healing__healAt", heal_at)
    if part_index != -1
      init |> set("four_step_healing__selectedBodypartIdx", part_index)


def create_tip_for_use_heal_decline_reason(item : EntityId;
                                           reason : int;
                                           declined_from_server : bool = false)
  debug_use_item_decline_reason(item, "{reason}", PREFIX, declined_from_server)
  if declined_from_server
    return
  if reason == int(CanUseHealResponse.FullHp)
    create_status_tip("status_tip_full_health")
  elif reason == int(CanUseHealResponse.NoHealItemsInBoxedItem)
    create_status_tip("status_tip_medkit_is_empty")
  elif reason == int(CanUseHealResponse.NoHealItems)
    create_status_tip("status_tip_no_healkits_in_inventory")
  elif reason == int(CanUseHealResponse.Downed)
    create_status_tip("status_tip_use_item_failed_in_downed")


[es(REQUIRE=item_heal)]
def try_use_heal(evt : TryUseItem;
                 eid aka item_eid : EntityId;
                 item__humanOwnerEid : EntityId;
                 item__containerOwnerEid : EntityId;
                 item__useTime : float;
                 item_heal__animationEnd : float;
                 item__unarmedUsage : bool;
                 four_step_healing__effectTemplateName : string;
                 var four_step_healing__effectEid : EntityId&;
                 item_heal_revive : Tag const?;
                 item_heal_hot : Tag const?;
                 item__usageSpeedModAffected : Tag const?;
                 item__currentBoxedItemCount : int const?;
                 item__downedTimeMultiplier : float = 1f;
                 item_heal__healTick : float = 0.0;
                 item_heal__healPerTick : float = 0.0;
                 item__amount = -1)
  query(evt.userEid) <| $ [es] (human_weap__currentGunEid : EntityId;
                                human_anim__vehicleSelected : EntityId;
                                transform : float3x4;
                                isAlive : bool;
                                isDowned : bool;
                                isInVehicle : bool;
                                human_net_phys__isInAir : bool;
                                human_inventory__canUseItems : bool;
                                human_inventory__canHeal : bool;
                                human_inventory__canLoadCharges : bool;
                                human_damage_model__sumHpAllBodyParts : float;
                                human_damage_model__sumMaxHpAllBodyParts : float;
                                human_inventory__pickupRemoveRadius : float;
                                human_weap_anim__reloadAtTime : float;
                                human_damage_model__parts : Object;
                                entity_mod_values : Object;
                                hero : Tag const?;
                                am_militant_bot : Tag const?;
                                var human_net_phys : HumanActor&;
                                var human_inventory__entityToUse : EntityId&;
                                var human_inventory_postponed_usage__state : int&;
                                var human_damage_model__selectedPartIdx : int&;
                                var human_damage_model__wishPartIdx : int&)
    if hero == null && am_militant_bot == null
      return
    if human_inventory_postponed_usage__state == int(PostponedUsageState.WaitForSwapToUnarmed) && has(human_inventory__entityToUse, "item_heal")
      human_damage_model__wishPartIdx = -1
      human_inventory__entityToUse = INVALID_ENTITY_ID
      return

    var canUseItem = check_human_can_use_item(isAlive, human_inventory__canUseItems, human_inventory__entityToUse)
    if canUseItem != CanUseItemResponse.Approved
      if canUseItem == CanUseItemResponse.OtherItemInUse
        sendEvent(evt.userEid, EventInterruptItemUse())
      create_tip_for_use_item_decline_reason(INVALID_ENTITY_ID, int(canUseItem), PREFIX)
      return

    human_damage_model__selectedPartIdx = human_damage_model__wishPartIdx
    if human_damage_model__selectedPartIdx < 0 || length(human_damage_model__parts) <= human_damage_model__selectedPartIdx
      let mostDamagedPart = get_most_damaged_part(human_damage_model__parts)
      human_damage_model__selectedPartIdx = find_index_of_part(human_damage_model__parts, mostDamagedPart)

    let curTime = get_sync_time()
    canUseItem = check_item_can_be_used(evt.userEid, item_eid, human_weap__currentGunEid, human_anim__vehicleSelected, human_net_phys,
                                        curTime, curTime, human_weap_anim__reloadAtTime, isDowned, human_net_phys__isInAir, isInVehicle,
                                        human_inventory__canHeal, human_inventory__canLoadCharges)
    if canUseItem != CanUseItemResponse.Approved
      create_tip_for_use_item_decline_reason(item_eid, int(canUseItem), PREFIX)
      return

    let canUseHeal = check_heal_can_be_used(evt.userEid, item_eid, item__humanOwnerEid, item__containerOwnerEid, transform[3], human_damage_model__selectedPartIdx, item__useTime, human_inventory__pickupRemoveRadius,
                                            human_damage_model__sumHpAllBodyParts, human_damage_model__sumMaxHpAllBodyParts, isDowned, item__unarmedUsage, item_heal_revive, item_heal_hot, item__currentBoxedItemCount)
    if canUseHeal != CanUseHealResponse.Approved
      create_tip_for_use_heal_decline_reason(item_eid, int(canUseHeal))
      return

    // special case for painkillers when player is downed (it doesn't fit to the postponed usage logic)
    if !isDowned && try_postponed_usage_on_unurmed_usage_item(evt.userEid, human_net_phys, human_inventory_postponed_usage__state)
      human_inventory__entityToUse = item_eid
      return

    human_damage_model__wishPartIdx = -1
    let useTime = get_item_use_time(item__useTime, item__downedTimeMultiplier, isDowned, item__usageSpeedModAffected != null, entity_mod_values)
    let animationEndTime = get_item_use_time(item_heal__animationEnd, item__downedTimeMultiplier, isDowned, item__usageSpeedModAffected != null, entity_mod_values)
    var healDuration = 0.0
    if item__amount > 0
      let totalMissingHp = human_damage_model__sumMaxHpAllBodyParts - human_damage_model__sumHpAllBodyParts
      let totalHealAmount = min(float(item__amount), totalMissingHp)
      healDuration = ceil(totalHealAmount / item_heal__healPerTick) * item_heal__healTick
    let useDuration = useTime + healDuration

    heal_use(evt.userEid, item_eid, curTime, useDuration + animationEndTime, useDuration, useTime, human_damage_model__selectedPartIdx, is_server(), four_step_healing__effectTemplateName, human_net_phys, four_step_healing__effectEid)


[es(tag=server)]
def try_use_heal_server(evt : RequestUseHeal;
                        eid aka human_eid : EntityId;
                        human_weap__currentGunEid : EntityId;
                        human_anim__vehicleSelected : EntityId;
                        human_inventory__entityToUse : EntityId;
                        transform : float3x4;
                        isAlive : bool;
                        isDowned : bool;
                        isInVehicle : bool;
                        human_net_phys__isInAir : bool;
                        human_inventory__canUseItems : bool;
                        human_inventory__canHeal : bool;
                        human_inventory__canLoadCharges : bool;
                        human_damage_model__sumHpAllBodyParts : float;
                        human_damage_model__sumMaxHpAllBodyParts : float;
                        human_inventory__pickupRemoveRadius : float;
                        human_weap_anim__reloadAtTime : float;
                        entity_mod_values : Object;
                        var human_net_phys : HumanActor&;
                        var human_damage_model__selectedPartIdx : int&)
  var canUseItem = check_human_can_use_item(isAlive, human_inventory__canUseItems, human_inventory__entityToUse)
  if canUseItem != CanUseItemResponse.Approved
    if canUseItem == CanUseItemResponse.OtherItemInUse
      sendEvent(human_eid, EventInterruptItemUse())
    send_net_event(human_eid, ResponseFailureUseHeal(itemEid = evt.itemEid, reason = int(canUseItem)), target_entity_conn(human_eid))
    return

  canUseItem = check_item_can_be_used(human_eid, evt.itemEid, human_weap__currentGunEid, human_anim__vehicleSelected, human_net_phys,
                                      get_sync_time(), evt.atTime, human_weap_anim__reloadAtTime, isDowned, human_net_phys__isInAir, isInVehicle,
                                      human_inventory__canHeal, human_inventory__canLoadCharges)
  if canUseItem != CanUseItemResponse.Approved
    send_net_event(human_eid, ResponseFailureUseHeal(itemEid = evt.itemEid, reason = int(canUseItem)), target_entity_conn(human_eid))
    return

  query(evt.itemEid) <| $ [es] (item__containerOwnerEid : EntityId;
                                item__humanOwnerEid : EntityId;
                                item__unarmedUsage : bool;
                                four_step_healing__effectTemplateName : string;
                                var four_step_healing__effectEid : EntityId&;
                                item_heal_revive : Tag const?;
                                item_heal_hot : Tag const?;
                                item__usageSpeedModAffected : Tag const?;
                                item__currentBoxedItemCount : int const?;
                                item__useTime : float;
                                item_heal__animationEnd : float;
                                item__downedTimeMultiplier : float = 1f;
                                item_heal__healTick : float = 0.0;
                                item_heal__healPerTick : float = 0.0;
                                item__amount = -1)
    let canUseHeal = check_heal_can_be_used(human_eid, evt.itemEid, item__humanOwnerEid, item__containerOwnerEid, transform[3], evt.partIndex, item__useTime, human_inventory__pickupRemoveRadius,
                                            human_damage_model__sumHpAllBodyParts, human_damage_model__sumMaxHpAllBodyParts, isDowned, item__unarmedUsage, item_heal_revive, item_heal_hot, item__currentBoxedItemCount)
    if canUseHeal != CanUseHealResponse.Approved
      send_net_event(human_eid, ResponseFailureUseHeal(itemEid = evt.itemEid, reason = int(CanUseItemResponse.End) + int(canUseHeal)), target_entity_conn(human_eid))
      return

    human_damage_model__selectedPartIdx = evt.partIndex
    let useTime = get_item_use_time(item__useTime, item__downedTimeMultiplier, isDowned, item__usageSpeedModAffected != null, entity_mod_values)
    let animationEndTime = get_item_use_time(item_heal__animationEnd, item__downedTimeMultiplier, isDowned, item__usageSpeedModAffected != null, entity_mod_values)
    var healDuration = 0.0
    if item__amount > 0
      let totalMissingHp = human_damage_model__sumMaxHpAllBodyParts - human_damage_model__sumHpAllBodyParts
      let totalHealAmount = min(float(item__amount), totalMissingHp)
      healDuration = ceil(totalHealAmount / item_heal__healPerTick) * item_heal__healTick
    let useDuration = useTime + healDuration

    heal_use(human_eid, evt.itemEid, evt.atTime, useDuration + animationEndTime, useDuration, useTime, evt.partIndex, true, four_step_healing__effectTemplateName, human_net_phys, four_step_healing__effectEid)


[es(tag=netClient, REQUIRE=hero)]
def heal_on_use_failure(evt : ResponseFailureUseHeal;
                        eid aka human_eid : EntityId)
  inventory_item_reset_using(human_eid)
  let lastCanUseItemResponseCode = int(CanUseItemResponse.End)
  if lastCanUseItemResponseCode <= evt.reason
    create_tip_for_use_heal_decline_reason(evt.itemEid, evt.reason - lastCanUseItemResponseCode, true)
  else
    create_tip_for_use_item_decline_reason(evt.itemEid, evt.reason, PREFIX, true)


[es(tag=server, REQUIRE_NOT=(item_healkit_magazine, item_heal_stream))]
def handle_heal_interrupted(evt : EventItemUseInterrupted;
                            eid : EntityId;
                            item__humanOwnerEid : EntityId;
                            item__useTime : float;
                            item__currentBoxedItemCount : int = 0)
  if item__currentBoxedItemCount > 0 || has(item__humanOwnerEid, "infinite_heal_items")
    return
  if get_sync_time() < (evt.startTime + item__useTime)
    return
  destroyEntity(eid)


[es(tag=server, REQUIRE_NOT=item_healkit_magazine)]
def handle_heal_stream_interrupted(evt : EventItemUseInterrupted;
                                   eid aka item_eid : EntityId;
                                   item__humanOwnerEid : EntityId;
                                   item_heal__healEffect : EntityId;
                                   item__useTime : float;
                                   item__amount : int)
  if has(item__humanOwnerEid, "infinite_heal_items")
    return
  if get_sync_time() < (evt.startTime + item__useTime)
    return

  destroyEntity(item_heal__healEffect)
  if item__amount <= 0
    destroyEntity(item_eid)


[es(tag=server, REQUIRE=item_heal, REQUIRE_NOT=item_healkit_magazine)]
def handle_heal_used(evt : EventOnLootItemUsed;
                     eid : EntityId;
                     item__humanOwnerEid : EntityId;
                     item__currentBoxedItemCount : int = 0;
                     item__amount = 0)
  if item__currentBoxedItemCount > 0 || item__amount > 0 || has(item__humanOwnerEid, "infinite_heal_items")
    return
  destroyEntity(eid)


[es(tag=gameClient, REQUIRE=item_heal)]
def on_heal_quick_used(evt : EventQuickUseItemUsed; eid : EntityId;
                       openHealingDollOnUse : Tag const?)
  if openHealingDollOnUse == null
    sendEvent(eid, TryUseItem(userEid = evt.userEid))
    return
  query(evt.userEid) <| $ [es] (human_inventory__entityToUse : EntityId;
                                human_damage_model__parts : Object)
    if human_inventory__entityToUse != INVALID_ENTITY_ID
      sendEvent(evt.userEid, EventInterruptItemUse())
    elif verify_healing_attempt(evt.userEid, eid)
      if get_damaged_parts_count(human_damage_model__parts) == 1
        sendEvent(eid, TryUseItem(userEid = evt.userEid))
      else
        sendEvent(eid, CmdShowHealingDoll())
    else
      show_healing_tip(evt.userEid, eid)


[es(on_appear, REQUIRE=painkillerEffect)]
def kill_pain_by_painkiller(evt : Event;
                            game_effect__attachedTo : EntityId)
  reset_pain_progress(game_effect__attachedTo)


[es(tag=gameClient, REQUIRE=watchedByPlr)]
def update_ui_healing_info(info : ParallelUpdateFrameDelayed;
                           eid : EntityId;
                           itemContainer : EidList;
                           var ui__hasSelfRevives : bool&;
                           var ui__hasInjectors : bool&;
                           var ui__hasAmpoules : bool&)
  ui__hasSelfRevives = get_revive_item(eid, itemContainer) != INVALID_ENTITY_ID
  ui__hasInjectors = get_hot_heal_item(eid, itemContainer) != INVALID_ENTITY_ID
  ui__hasAmpoules = get_heal_item(eid, itemContainer) != INVALID_ENTITY_ID
