require ecs
require ecs.safe
require math.base
require game.es.action_common
require game.events.events
require game.events.events_game
require game.es.external_inventory_common
require game.es.use_object_common
require game.events.events_active_matter
require DagorSystem
require DngNet


def process_external_inventory_accesspoint_use(hero_eid : EntityId;
                                               accesspoint_eid : EntityId;
                                               external_inventory_interactor__accesspointEid : EntityId)
  if external_inventory_interactor__accesspointEid != accesspoint_eid
    run_action(hero_eid, "pickup")
    open_external_inventory(hero_eid, accesspoint_eid)
  else
    close_external_inventory()


[es(tag=(gameClient, server), REQUIRE=external_inventory_accesspoint)]
def on_external_inventory_accesspoint_offline_use(evt : CmdUse;
                                                  eid aka accesspoint_eid : EntityId;
                                                  external_inventory_accesspoint__accessOnUse : bool = true)
  query(evt.requesterEid) <| $ [es(REQUIRE=hero)] (external_inventory_interactor__accesspointEid : EntityId)
    if external_inventory_accesspoint__accessOnUse
      process_external_inventory_accesspoint_use(
        evt.requesterEid,
        accesspoint_eid,
        external_inventory_interactor__accesspointEid)


[es(tag=netClient, REQUIRE=watchedByPlr)]
def on_external_inventory_accesspoint_online_use(evt : HumanUseObjectRequest;
                                                 eid aka hero_eid : EntityId;
                                                 external_inventory_interactor__accesspointEid : EntityId)
  query(evt.objectEid) <| $ [es(REQUIRE=external_inventory_accesspoint)] (external_inventory_accesspoint__accessOnUse : bool = true)
    if external_inventory_accesspoint__accessOnUse
      process_external_inventory_accesspoint_use(
        hero_eid,
        evt.objectEid,
        external_inventory_interactor__accesspointEid)


[es(tag=gameClient)]
def external_inventory_menu_closed(evt : EventInventoryClosed)
  find_query() <| $ [es(REQUIRE=(watchedByPlr))] (external_inventory_interactor__inventoryEid : EntityId)
    if external_inventory_interactor__inventoryEid != INVALID_ENTITY_ID
      close_external_inventory()
    return true


[es(tag=gameClient, REQUIRE=watchedByPlr, no_order)]
def external_inventory_accesspoint_distance_check(act : ParallelUpdateFrameDelayed;
                                                  eid : EntityId;
                                                  external_inventory_interactor__accesspointEid : EntityId;
                                                  external_inventory_interactor__extraUseDist : float)
  if (external_inventory_interactor__accesspointEid != INVALID_ENTITY_ID &&
      !hero_human_use_object_weak_check(eid, external_inventory_interactor__accesspointEid, external_inventory_interactor__extraUseDist))
    close_external_inventory()


[es(tag=server)]
def on_cmd_use_external_inventory_accesspoint_request(evt : CmdUseExternalInventoryAccesspointRequest;
                                                      eid aka accesspoint_eid : EntityId)
  if hero_human_use_object_weak_check(evt.heroEid, accesspoint_eid)
    sendEventImmediate(eid, CmdUseExternalInventoryAccesspoint(heroEid = evt.heroEid))


[es(tag=server)]
def on_cmd_use_external_inventory_accesspoint(evt : CmdUseExternalInventoryAccesspoint;
                                              eid aka accesspoint_eid : EntityId;
                                              external_inventory_accesspoint__inventoryEid : EntityId)
  query(evt.heroEid) <| $ [es] (var external_inventory_interactor__accesspointEid : EntityId&;
                                var external_inventory_interactor__inventoryEid : EntityId&)

    assume accesspointIventoryEid = external_inventory_accesspoint__inventoryEid
    let inventoryEid = accesspointIventoryEid != INVALID_ENTITY_ID ? accesspointIventoryEid : accesspoint_eid
    external_inventory_interactor__inventoryEid = inventoryEid
    external_inventory_interactor__accesspointEid = accesspoint_eid

    sendEventImmediate(
      evt.heroEid,
      CmdValidateActorUseExternalInventoryAccesspoint(actorEid = evt.heroEid,
                                                        inventoryEid = inventoryEid,
                                                        accesspointEid = accesspoint_eid))

    if (external_inventory_interactor__inventoryEid == INVALID_ENTITY_ID ||
       external_inventory_interactor__accesspointEid == INVALID_ENTITY_ID)
      return

    sendEvent(accesspoint_eid, EventExternalInventoryAccesspointAccessed(heroEid = evt.heroEid))
    sendEvent(inventoryEid, EventExternalInventoryContainerAccessedByHero(heroEid = evt.heroEid))


[es(tag=server)]
def on_cmd_close_external_inventory_request(evt : CmdCloseExternalInventoryRequest;
                                            var external_inventory_interactor__accesspointEid : EntityId&;
                                            var external_inventory_interactor__inventoryEid : EntityId&)
  external_inventory_interactor__accesspointEid = INVALID_ENTITY_ID
  external_inventory_interactor__inventoryEid = INVALID_ENTITY_ID


[es(tag=server, track=item__isOnGround, on_appear, on_disappear,
  REQUIRE=(external_inventory_accesspoint, item__isOnGround))]
def on_external_inventory_accesspoint_ground_state_changed(evt : Event;
                                                           eid aka accesspoint_eid : EntityId)
  query() <| $ [es] (var external_inventory_interactor__accesspointEid : EntityId&;
                     var external_inventory_interactor__inventoryEid : EntityId&)
    if external_inventory_interactor__accesspointEid == accesspoint_eid
      external_inventory_interactor__accesspointEid = INVALID_ENTITY_ID
      external_inventory_interactor__inventoryEid = INVALID_ENTITY_ID


[es(tag=server)]
def validate_actor_use_external_inventory_accesspoint(evt : CmdValidateActorUseExternalInventoryAccesspoint;
                                                      eid aka actor_eid : EntityId;
                                                      team aka actor_team : int;
                                                      var external_inventory_interactor__accesspointEid : EntityId&;
                                                      var external_inventory_interactor__inventoryEid : EntityId&)
  query(evt.accesspointEid) <| $ [es] (team aka accesspoint_team : int)
    if accesspoint_team != -1 && accesspoint_team != actor_team
      send_net_event(actor_eid, ShowStatusTip(statusTip = "status_tip_use_external_inventory_access_denied_wrong_team"))
      external_inventory_interactor__accesspointEid = INVALID_ENTITY_ID
      external_inventory_interactor__inventoryEid = INVALID_ENTITY_ID