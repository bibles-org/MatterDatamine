require ecs
require app
require net
require ecs.common
require ecs.safe
require math
require DngNet
require DngHuman
require game.events.events_active_matter
require game.es.revive_common
require game.utils.net_utils
require game.events.events
require game.es.inventory_equipment_common
require game.es.inventory_common
require game.utils.team
require game.es.entity_mods_common
require game.es.human_inventory_postponed_usage_common
require game.es.status_tip_common
require game.es.interrupt_item_use_common


let private PREFIX = "CORTICAL VAULT"


enum CanUseCorticalVaultResponse
  Approved
  Declined
  UnarmedUsage
  NoUseTime
  TargetBroken
  TargetDisconected
  TargetAlreadyAlive
  TargetIsEnemy
  UsingAmReserved
  NotEnoughAm


def cortical_vault_use(human_eid : EntityId;
                       item_eid : EntityId;
                       target_eid : EntityId;
                       item_player_owner_eid : EntityId;
                       start_time : float;
                       duration : float;
                       server : bool;
                       cortical_vault__effectTemplateName : string;
                       var human_net_phys : HumanActor&;
                       var cortical_vault__usingAmReserved : int&;
                       var cortical_vault__effectEid : EntityId&)
  inventory_item_prepare_using(human_eid, item_eid, human_eid, start_time, duration)
  human_net_phys.phys.currentState |> human_phys_state_set_stoppedSprint(true)
  create_teammate_revive_effect(human_eid, item_player_owner_eid, cortical_vault__effectTemplateName, server && is_true_net_server(), cortical_vault__effectEid)
  spend_am_for_revive(item_eid, target_eid, item_player_owner_eid, cortical_vault__usingAmReserved)

  if !server
    send_net_event(human_eid, RequestUseCorticalVault(itemEid = item_eid, targetEid = target_eid, atTime = start_time))
  sendEvent(item_eid, EventOnItemStartUse(userEid = human_eid, targetEid = human_eid))


def spend_am_for_revive(item_eid : EntityId;
                        target_eid : EntityId;
                        item_player_owner_eid : EntityId;
                        var cortical_vault__usingAmReserved : int&)
  var usedFreeResurrections = false
  query(target_eid) <| $ [es] (possessedByPlr : EntityId)
    query(possessedByPlr) <| $ [es] (var active_matter_bot_player__freeResurrections : int?)
      if (active_matter_bot_player__freeResurrections ?? 0) > 0
        *active_matter_bot_player__freeResurrections = (*active_matter_bot_player__freeResurrections) - 1
        usedFreeResurrections = true
        return
  if usedFreeResurrections
    return
  var am_in_cortical = 0
  query(item_eid) <| $[es] (am_storage__value aka cortical_am_storage__value : int)
    am_in_cortical = cortical_am_storage__value
  let needAmForRevive = get_current_revive_price(item_player_owner_eid)
  let remainingPrice = max(0, needAmForRevive - am_in_cortical)
  if remainingPrice > 0
    sendEvent(target_eid, CmdChangeActiveMatterBalance(change = -remainingPrice, reason = "cortical_vault_revive"))
  cortical_vault__usingAmReserved = remainingPrice


def check_cortical_vault_can_be_used(revived_player : EntityId;
                                     item_eid : EntityId;
                                     use_time : float;
                                     actor_team : int;
                                     am_storage__value : int;
                                     item__unarmedUsage : bool;
                                     cortical_vault__reviveAllowed : bool;
                                     cortical_vault__usingAmReserved : int)
  if !item__unarmedUsage
    return CanUseCorticalVaultResponse.UnarmedUsage

  if use_time <= 0.0f
    return CanUseCorticalVaultResponse.NoUseTime

  if cortical_vault__usingAmReserved > 0
    return CanUseCorticalVaultResponse.UsingAmReserved

  if !doesEntityExist(revived_player) || !cortical_vault__reviveAllowed
    return CanUseCorticalVaultResponse.TargetBroken

  var canUseCorticalVault = CanUseCorticalVaultResponse.Declined
  query(revived_player) <| $ [es] (team aka cortical_vault_team : int; disconnected : bool; possessed : EntityId)
    if actor_team != cortical_vault_team
      canUseCorticalVault = CanUseCorticalVaultResponse.TargetIsEnemy
      return

    if disconnected
      canUseCorticalVault = CanUseCorticalVaultResponse.TargetDisconected
      return

    var isAlreadyAlive = false // already revived by other means
    query(possessed) <| $ [es] (isAlive : bool)
      isAlreadyAlive = isAlive
    if isAlreadyAlive
      canUseCorticalVault = CanUseCorticalVaultResponse.TargetAlreadyAlive
      return

    var am_in_cortical = 0
    query(item_eid) <| $[es] (am_storage__value aka cortical_am_storage__value : int)
      am_in_cortical = cortical_am_storage__value
    let needAmForRevive = get_current_revive_price(revived_player)
    let revivePrice = max(0, needAmForRevive - am_in_cortical)
    if am_storage__value < revivePrice
      canUseCorticalVault = CanUseCorticalVaultResponse.NotEnoughAm
      return
    canUseCorticalVault = CanUseCorticalVaultResponse.Approved
  return canUseCorticalVault


def create_teammate_revive_effect(human_eid : EntityId;
                                  item_player_owner_eid : EntityId;
                                  effect_template_name : string;
                                  server : bool;
                                  var revive_effect_eid : EntityId&)
  let effect_template_name_full = effect_template_name + (server ? "" : "+teammate_revive_client")
  revive_effect_eid = createEntity(effect_template_name_full) <| $(init)
    init |> set("game_effect__attachedTo", human_eid)
    init |> set("teammate_revive_effect__playerItemOwner", item_player_owner_eid)

def calculate_cortical_vault_track_pos(cortical_vault_eid : EntityId)
  var pos : float3
  var posSet = false
  query(cortical_vault_eid) <| $ [es] (item__containerOwnerEid : EntityId const?;
                                       item__humanOwnerEid : EntityId const?)
    if item__containerOwnerEid != null
      query(*item__containerOwnerEid) <| $ [es] (transform : float3x4)
        pos = transform[3]
        posSet = true

    if !posSet && item__humanOwnerEid != null
      query(*item__humanOwnerEid) <| $ [es] (transform : float3x4)
        pos = transform[3]
        posSet = true

  return pos


def create_tip_for_use_cortical_vault_decline_reason(item : EntityId;
                                                     reason : int;
                                                     declined_from_server : bool = false;
                                                     current_am : int = 0;
                                                     revive_am : int = 0)
  debug_use_item_decline_reason(item, "{reason}", PREFIX, declined_from_server)
  if declined_from_server
    return
  if reason == int(CanUseCorticalVaultResponse.TargetIsEnemy)
    create_status_tip("status_tip_revive_enemy")
  elif reason == int(CanUseCorticalVaultResponse.TargetBroken)
    create_status_tip("status_tip_revive_broken_player")
  elif reason == int(CanUseCorticalVaultResponse.TargetDisconected)
    create_status_tip("status_tip_revive_disconnected_player")
  elif reason == int(CanUseCorticalVaultResponse.NotEnoughAm)
    var am_in_cortical = 0
    query(item) <| $[es] (am_storage__value : int)
      am_in_cortical = am_storage__value
    using() <| $(var data : Object)
      set(data, "0", current_am + am_in_cortical)
      set(data, "1", revive_am)
      create_status_tip("status_tip_revive_not_enough_am", false, ecs_addr(data))


[es(REQUIRE=cortical_vault)]
def try_cortical_vault_use(evt : TryUseItem;
                           eid aka item_eid : EntityId;
                           playerItemOwner : EntityId;
                           item__useTime : float;
                           cortical_vault__effectTemplateName : string;
                           item__unarmedUsage : bool;
                           var cortical_vault__effectEid : EntityId&;
                           var cortical_vault__usingAmReserved : int&;
                           item__usageSpeedModAffected : Tag const?;
                           cortical_vault__reviveAllowed : bool = true)
  query(evt.userEid) <| $ [es] (human_anim__vehicleSelected : EntityId;
                                human_weap__currentGunEid : EntityId;
                                team aka actor_team : int;
                                am_storage__value : int;
                                isDowned : bool;
                                isAlive : bool;
                                isInVehicle : bool;
                                human_net_phys__isInAir : bool;
                                human_inventory__canUseItems : bool;
                                human_inventory__canHeal : bool;
                                human_inventory__canLoadCharges : bool;
                                entity_mod_values : Object;
                                human_weap_anim__reloadAtTime : float;
                                var human_net_phys : HumanActor&;
                                var human_inventory__entityToUse : EntityId&;
                                var human_inventory__targetToUse : EntityId&;
                                var human_inventory_postponed_usage__state : int&)
    if human_inventory_postponed_usage__state == int(PostponedUsageState.WaitForSwapToUnarmed) && human_inventory__entityToUse == item_eid
      human_inventory__entityToUse = INVALID_ENTITY_ID
      return

    var canUseItem = check_human_can_use_item(isAlive, human_inventory__canUseItems, human_inventory__entityToUse)
    if canUseItem != CanUseItemResponse.Approved
      if canUseItem == CanUseItemResponse.OtherItemInUse
        sendEvent(evt.userEid, EventInterruptItemUse())
      create_tip_for_use_item_decline_reason(item_eid, int(canUseItem), PREFIX)
      return

    let curTime = get_sync_time()
    canUseItem = check_item_can_be_used(evt.userEid, item_eid, human_weap__currentGunEid, human_anim__vehicleSelected, human_net_phys,
                                        curTime, curTime, human_weap_anim__reloadAtTime, isDowned, human_net_phys__isInAir, isInVehicle,
                                        human_inventory__canHeal, human_inventory__canLoadCharges)
    if canUseItem != CanUseItemResponse.Approved
      create_tip_for_use_item_decline_reason(item_eid, int(canUseItem), PREFIX)
      return

    let canUseCorticalVault = check_cortical_vault_can_be_used(playerItemOwner, item_eid, item__useTime, actor_team, am_storage__value, item__unarmedUsage, cortical_vault__reviveAllowed, cortical_vault__usingAmReserved)
    if canUseCorticalVault != CanUseCorticalVaultResponse.Approved
      create_tip_for_use_cortical_vault_decline_reason(item_eid, int(canUseCorticalVault), false, am_storage__value, get_current_revive_price(playerItemOwner))
      return

    if try_postponed_usage_on_unurmed_usage_item(evt.userEid, human_net_phys, human_inventory_postponed_usage__state)
      human_inventory__entityToUse = item_eid
      human_inventory__targetToUse = evt.targetEid
      return

    let useTime = get_item_use_time(item__useTime, item__usageSpeedModAffected != null, entity_mod_values)
    cortical_vault_use(evt.userEid, item_eid, evt.targetEid, playerItemOwner, curTime, useTime, is_server(), cortical_vault__effectTemplateName, human_net_phys, cortical_vault__usingAmReserved, cortical_vault__effectEid)


[es(tag=server)]
def try_cortical_vault_use_server(evt : RequestUseCorticalVault;
                                  eid aka human_eid : EntityId;
                                  human_anim__vehicleSelected : EntityId;
                                  human_weap__currentGunEid : EntityId;
                                  human_inventory__entityToUse : EntityId;
                                  team aka actor_team : int;
                                  am_storage__value : int;
                                  isDowned : bool;
                                  isAlive : bool;
                                  isInVehicle : bool;
                                  human_net_phys__isInAir : bool;
                                  human_inventory__canUseItems : bool;
                                  human_inventory__canHeal : bool;
                                  human_inventory__canLoadCharges : bool;
                                  entity_mod_values : Object;
                                  human_weap_anim__reloadAtTime : float;
                                  var human_net_phys : HumanActor&)
  var canUseItem = check_human_can_use_item(isAlive, human_inventory__canUseItems, human_inventory__entityToUse)
  if canUseItem != CanUseItemResponse.Approved
    if canUseItem == CanUseItemResponse.OtherItemInUse
      sendEvent(human_eid, EventInterruptItemUse())
    send_net_event(human_eid, ResponseFailureUseCorticalVault(itemEid = evt.itemEid, reason = int(canUseItem)), target_entity_conn(human_eid))
    return

  canUseItem = check_item_can_be_used(human_eid, evt.itemEid, human_weap__currentGunEid, human_anim__vehicleSelected, human_net_phys,
                                      get_sync_time(), evt.atTime, human_weap_anim__reloadAtTime, isDowned, human_net_phys__isInAir, isInVehicle,
                                      human_inventory__canHeal, human_inventory__canLoadCharges)
  if canUseItem != CanUseItemResponse.Approved
    send_net_event(human_eid, ResponseFailureUseCorticalVault(itemEid = evt.itemEid, reason = int(canUseItem)), target_entity_conn(human_eid))
    return

  query(evt.itemEid) <| $ [es(REQUIRE=cortical_vault)] (item__unarmedUsage : bool = false;
                                                        item__useTime : float;
                                                        playerItemOwner : EntityId;
                                                        cortical_vault__effectTemplateName : string;
                                                        var cortical_vault__effectEid : EntityId&;
                                                        var cortical_vault__usingAmReserved : int&;
                                                        item__usageSpeedModAffected : Tag const?;
                                                        cortical_vault__reviveAllowed : bool = true)
    let canUseCorticalVault = check_cortical_vault_can_be_used(playerItemOwner, evt.itemEid, item__useTime, actor_team, am_storage__value, item__unarmedUsage, cortical_vault__reviveAllowed, cortical_vault__usingAmReserved)
    if canUseCorticalVault != CanUseCorticalVaultResponse.Approved
      send_net_event(human_eid, ResponseFailureUseCorticalVault(itemEid = evt.itemEid, reason = int(CanUseItemResponse.End) + int(canUseCorticalVault)), target_entity_conn(human_eid))
      return

    let useTime = get_item_use_time(item__useTime, item__usageSpeedModAffected != null, entity_mod_values)
    cortical_vault_use(human_eid, evt.itemEid, evt.targetEid, playerItemOwner, evt.atTime, useTime, true, cortical_vault__effectTemplateName, human_net_phys, cortical_vault__usingAmReserved, cortical_vault__effectEid)


[es(tag=netClient, REQUIRE=hero)]
def cortical_vault_on_use_failure(evt : ResponseFailureUseCorticalVault;
                                  eid aka human_eid : EntityId;
                                  am_storage__value : int;
                                  var cortical_vault__usingAmReserved : int&)
  inventory_item_reset_using(human_eid)
  cortical_vault__usingAmReserved = 0
  let lastCanUseItemResponseCode = int(CanUseItemResponse.End)
  if lastCanUseItemResponseCode <= evt.reason
    query(evt.itemEid) <| $ [es] (playerItemOwner : EntityId)
      create_tip_for_use_cortical_vault_decline_reason(evt.itemEid, evt.reason - lastCanUseItemResponseCode, true, am_storage__value, get_current_revive_price(playerItemOwner))
  else
    create_tip_for_use_item_decline_reason(evt.itemEid, evt.reason, PREFIX, true)


[es(tag=server, on_appear, REQUIRE=cortical_vault_test)]
def cortical_vault_test_init(evt : Event;
                             team : int;
                             var item__lastContainerOwnerEid : EntityId&;
                             var playerItemOwner : EntityId&)
  playerItemOwner = create_test_player(team)
  item__lastContainerOwnerEid = playerItemOwner


[es(tag=gameClient, on_appear, REQUIRE=cortical_vault, after=recognizable_item_appear)]
def cortical_vault_init_recognition_priority(evt : Event;
                                             playerItemOwner : EntityId;
                                             var item__uiSortingPriority : int&)
  if is_teams_friendly(get_local_player_team(), get_player_team(playerItemOwner))
    item__uiSortingPriority = INT_MAX
  else
    item__uiSortingPriority = 0


[es(tag=gameClient, on_appear, REQUIRE=player)]
def cortical_vault_init_recognition_priority_on_player_appear(evt : Event;
                                                              eid : EntityId;
                                                              team : int)
  find_query() <| $ [es(REQUIRE=cortical_vault)] (playerItemOwner : EntityId;
                                                  var item__uiSortingPriority : int&)
    if playerItemOwner == eid
      if is_teams_friendly(get_local_player_team(), team)
        item__uiSortingPriority = INT_MAX
      else
        item__uiSortingPriority = 0
      return true
    return false


[es(tag=server, REQUIRE=cortical_vault)]
def cortical_vault_usage_interrupted(evt : EventItemUseInterrupted;
                                     var cortical_vault__usingAmReserved : int&)
  if cortical_vault__usingAmReserved > 0
    sendEvent(evt.userEid, CmdChangeActiveMatterBalance(change = cortical_vault__usingAmReserved, reason = "cortical_vault_revive_interrupted"))
    cortical_vault__usingAmReserved = 0


[es(tag=server, on_appear)]
def cortical_vault_in_inventory_appear(evt : Event;
                                       eid : EntityId;
                                       cortical_vault_in_inventory__updateInterval : float;
                                       var cortical_vault_in_inventory__updateAt : float&;
                                       var cortical_vault_in_inventory__trackPos : float3&)
  cortical_vault_in_inventory__updateAt = eid_frnd(eid) * cortical_vault_in_inventory__updateInterval
  cortical_vault_in_inventory__trackPos = calculate_cortical_vault_track_pos(eid)


[es(tag=server, no_order)]
def cortical_vault_in_inventory_update(act : ParallelUpdateFrameDelayed;
                                       eid aka cortical_vault_eid : EntityId;
                                       playerItemOwner : EntityId;
                                       cortical_vault_in_inventory__updateInterval : float;
                                       var cortical_vault_in_inventory__updateAt : float&;
                                       var cortical_vault_in_inventory__trackPos : float3&)
  if act.curTime < cortical_vault_in_inventory__updateAt
    return

  cortical_vault_in_inventory__updateAt = act.curTime + cortical_vault_in_inventory__updateInterval
  cortical_vault_in_inventory__trackPos = calculate_cortical_vault_track_pos(eid)

  query(playerItemOwner) <| $ [es] (team aka cortical_vault_team : int)
    query() <| $ [es(REQUIRE=player, REQUIRE_NOT=playerIsBot)] (eid aka player_eid : EntityId;
                                                                team aka player_team : int)
      if cortical_vault_team == player_team
        send_net_event(
          cortical_vault_eid,
          EventCorticalVaultSyncPos(pos = cortical_vault_in_inventory__trackPos),
          target_entity_conn(player_eid))


[es(tag=gameClient, no_order)]
def cortical_vault_track_pos_client(evt : EventCorticalVaultSyncPos;
                                    var cortical_vault_in_inventory__trackPos : float3&)
  cortical_vault_in_inventory__trackPos = evt.pos


[es(tag=server, on_appear, track=possessedByPlr)]
def equip_cortical_vault_appear(evt : Event;
                                eid aka hero_eid : EntityId;
                                equip_cortical_vault__itemTemplate : string;
                                possessedByPlr : EntityId;
                                var equip_cortical_vault__equipped : bool&)
  if possessedByPlr == INVALID_ENTITY_ID
    return

  if equip_cortical_vault__equipped
    return

  equip_cortical_vault__equipped = true

  create_item_in_equipment(equip_cortical_vault__itemTemplate, "cortical_vault", hero_eid) <| $(init)
    init |> set("playerItemOwner", possessedByPlr)


[es(tag=server, REQUIRE=cortical_vault)]
def handle_cortical_vault_used(evt : EventOnLootItemUsed;
                               eid : EntityId;
                               var cortical_vault__usingAmReserved : int&)
  cortical_vault__usingAmReserved = 0
  destroyEntity(eid)
