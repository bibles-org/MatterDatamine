require ecs
require app
require DngNet
require game.events.events_active_matter
require game.events.inventory_events
require game.events.events_game


def stop_inspecting_ammo_count(var ammo_count_knowledge_controller__inspectingAffectEid : EntityId&)
  destroyEntity(ammo_count_knowledge_controller__inspectingAffectEid)
  ammo_count_knowledge_controller__inspectingAffectEid = INVALID_ENTITY_ID


def start_inspecting_ammo_count(item_eid : EntityId;
                                actor_eid : EntityId;
                                ammo_count_knowledge_controller__inspectingAffectTemplate : string;
                                var ammo_count_knowledge_controller__inspectingAffectEid : EntityId&)
  assume inspectingAffectEid = ammo_count_knowledge_controller__inspectingAffectEid

  stop_inspecting_ammo_count(inspectingAffectEid)
  inspectingAffectEid = createEntitySync(ammo_count_knowledge_controller__inspectingAffectTemplate) <| $ [es] (var init : ComponentsInitializer)
    init |> set("ammo_count_knowledge_inspecting__startTimestamp", get_sync_time())
    init |> set("ammo_count_knowledge_inspecting__itemEid", item_eid)
    init |> set("ammo_count_knowledge_inspecting__owner", actor_eid)
    init |> set("game_effect__attachedTo", actor_eid)

  send_net_event(actor_eid, RequestInterruptItemUse())


[es(tag=gameClient, on_disappear)]
def ammo_count_knowledge_inspecting_on_disappear(evt : Event;
                                                 eid aka game_effect_eid : EntityId;
                                                 game_effect__timeToDestroy : float;
                                                 ammo_count_knowledge_inspecting__itemEid : EntityId;
                                                 ammo_count_knowledge_inspecting__startTimestamp : float;
                                                 ammo_count_knowledge_inspecting__owner : EntityId)
  query(ammo_count_knowledge_inspecting__owner) <| $ [es] (var ammo_count_knowledge_controller__inspectingAffectEid : EntityId&)
    if ammo_count_knowledge_controller__inspectingAffectEid == game_effect_eid
      ammo_count_knowledge_controller__inspectingAffectEid = INVALID_ENTITY_ID

  if get_sync_time() < ammo_count_knowledge_inspecting__startTimestamp + game_effect__timeToDestroy
    return

  send_net_event(ammo_count_knowledge_inspecting__owner, EventItemHolderInspectionFinished(holderEid = ammo_count_knowledge_inspecting__itemEid))


[es(tag=server)]
def ammo_count_known_on_inspected(evt : EventItemHolderInspectionFinished;
                                  eid : EntityId)
  query(evt.holderEid) <| $ [es] (var ammo_holder__ammoCountKnown : EidList&)
    ammo_holder__ammoCountKnown |> push(eid)


[es(tag=gameClient, REQUIRE=watchedByPlr)]
def request_check_ammo_item(evt : RqCheckAmmoItemHolder;
                            eid aka actor_eid : EntityId;
                            ammo_count_knowledge_controller__inspectingAffectTemplate : string;
                            var ammo_count_knowledge_controller__inspectingAffectEid : EntityId&)
  start_inspecting_ammo_count(evt.targetItemEid, actor_eid,
                              ammo_count_knowledge_controller__inspectingAffectTemplate,
                              ammo_count_knowledge_controller__inspectingAffectEid)


[es(tag=gameClient, REQUIRE=watchedByPlr)]
def request_stop_check_ammo_item(evt : RqStopCheckAmmoItemHolder;
                                 var ammo_count_knowledge_controller__inspectingAffectEid : EntityId&)
  stop_inspecting_ammo_count(ammo_count_knowledge_controller__inspectingAffectEid)


[es(tag=gameClient, REQUIRE=watchedByPlr)]
def stop_inspecting_ammo_count_on_inventory_menu_closed(evt : EventInventoryClosed;
                                                        var ammo_count_knowledge_controller__inspectingAffectEid : EntityId&)
  stop_inspecting_ammo_count(ammo_count_knowledge_controller__inspectingAffectEid)


[es(tag=gameClient, REQUIRE=watchedByPlr)]
def stop_inspecting_ammo_count_on_use_item(evt : TryUseItem)
  query(evt.userEid) <| $ [es] (var ammo_count_knowledge_controller__inspectingAffectEid : EntityId&)
    stop_inspecting_ammo_count(ammo_count_knowledge_controller__inspectingAffectEid)


def set_gun_ammo_count_known(gun_eid : EntityId;
                             known : bool)
  query(gun_eid) <| $ [es] (gun__owner : EntityId;
                            gun_mods__curModInSlots : Object const?;
                            var ammo_holder__ammoCountKnown : EidList?)
    if ammo_holder__ammoCountKnown != null
      if known
        *ammo_holder__ammoCountKnown |> push(gun__owner)
      else
        *ammo_holder__ammoCountKnown |> clear()
    elif gun_mods__curModInSlots != null
      query(get_Eid((*gun_mods__curModInSlots)["magazine"]) ?? INVALID_ENTITY_ID) <| $ [es] (var ammo_holder__ammoCountKnown : EidList&)
        if known
          ammo_holder__ammoCountKnown |> push(gun__owner)
        else
          ammo_holder__ammoCountKnown |> clear()


[es(tag=server, on_event=EventShotDry)]
def ammo_count_known_on_shot_dry(evt : Event;
                                 eid aka gun_eid : EntityId)
  query(gun_eid) <| $ [es] (gun_jamming__isJammed : bool = false)
    if !gun_jamming__isJammed
      set_gun_ammo_count_known(gun_eid, true)


[es(tag=server)]
def ammo_count_known_on_item_holder_loading_finished(evt : EventItemHolderLoadingFinished; eid : EntityId)
  query(evt.holderEid) <| $ [es] (item_holder__maxItemCount : int;
                                  var ammo_holder__ammoCountKnown : EidList&)
    if evt.loadedItemCount == 0 || evt.loadedItemCount == item_holder__maxItemCount
      ammo_holder__ammoCountKnown |> push(eid)


[es(tag=gameClient, REQUIRE=watchedByPlr)]
def ammo_count_known_on_check_ammo_marker(evt : EventCheckWeaponMarker;
                                          eid : EntityId;
                                          human_weap__currentGunEid : EntityId)
  if human_weap__currentGunEid |> has("ammo_holder__ammoCountKnown")
    send_net_event(eid, EventItemHolderInspectionFinished(holderEid = human_weap__currentGunEid))
  else
    query(human_weap__currentGunEid) <| $ [es] (gun_mods__curModInSlots : Object const)
      let magazineEid = get_Eid(gun_mods__curModInSlots["magazine"]) ?? INVALID_ENTITY_ID
      send_net_event(eid, EventItemHolderInspectionFinished(holderEid = magazineEid))


[es(tag=server, on_event=EventShot)]
def ammo_count_known_on_shot(evt : Event;
                             eid : EntityId;
                             gun__owner : EntityId;
                             gun__ammo : int;
                             var ammo_holder__ammoCountKnown : EidList?)
  if gun__ammo == 0 && ammo_holder__ammoCountKnown != null
    *ammo_holder__ammoCountKnown |> push(gun__owner)
    return

  set_gun_ammo_count_known(eid, false)


[es(tag=server)]
def ammo_count_known_on_gun_ammo_load(evt : NotifyGunBoxedAmmoLoadingEnd; eid : EntityId)
  query(evt.gunEid) <| $ [es] (var ammo_holder__ammoCountKnown : EidList&)
    ammo_holder__ammoCountKnown |> push(eid)


[es(tag=server, after=unload_ammo_es)]
def ammo_count_known_on_unload_ammo(evt : CmdUnloadAmmo;
                                    gun__owner : EntityId;
                                    gun__ammo : int;
                                    var ammo_holder__ammoCountKnown : EidList&)
  if gun__ammo == 0
    ammo_holder__ammoCountKnown |> push(gun__owner)


[es(tag=server, track=item__humanOwnerEid)]
def ammo_count_known_on_move(evt : Event;
                             item__humanOwnerEid : EntityId;
                             item_holder__maxItemCount : int;
                             item__currentBoxedItemCount : int;
                             var ammo_holder__ammoCountKnown : EidList&)
  if item__humanOwnerEid != INVALID_ENTITY_ID
    let wasKnown = ammo_holder__ammoCountKnown |> has_value(item__humanOwnerEid)
    ammo_holder__ammoCountKnown |> clear()
    if wasKnown || item_holder__maxItemCount == item__currentBoxedItemCount || item__currentBoxedItemCount == 0
      ammo_holder__ammoCountKnown |> push(item__humanOwnerEid)


[es(tag=server, track=item__recognizedByPlayers)]
def ammo_count_known_by_recognition(evt : Event;
                                    item_holder__maxItemCount : int;
                                    item__currentBoxedItemCount : int;
                                    item__recognizedByPlayers : EidList;
                                    var ammo_holder__ammoCountKnown : EidList&)
  if item_holder__maxItemCount == item__currentBoxedItemCount || item__currentBoxedItemCount == 0
    for rec in item__recognizedByPlayers
      query(rec) <| $ [es] (possessed : EntityId)
        if !has_value(ammo_holder__ammoCountKnown, possessed)
          push(ammo_holder__ammoCountKnown, possessed)
