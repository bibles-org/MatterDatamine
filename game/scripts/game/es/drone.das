require ecs
require app
require net
require game.events.events
require game.events.events_active_matter
require math.base
require game.events.events_game
require DngHelicopter
require HelicopterPhys
require PhysVars
require game.events.events_game
require DagorMath
require DngDm
require HumanPhys
require game.es.inventory_item_common
require game.es.inventory_checks_common
require game.events.inventory_events
require game.es.inventory_common
require DngHuman
require game.es.status_tip_common
require game.es.level_common


[es(on_appear, REQUIRE=isDrone)]
def drone_startup(evt : Event;
                  var drone__owner : EntityId&;
                  var drone__immortalAt : float&;
                  drone__immortalPeriodOnAppear : float;
                  playerOwnerEid : EntityId;
                  var helicopter_net_phys : HelicopterActor)
  helicopter_phys_set_engine_started(helicopter_net_phys.phys)
  query(playerOwnerEid) <| $ [es] (possessed : EntityId)
    drone__owner = possessed
    drone__immortalAt = get_sync_time() + drone__immortalPeriodOnAppear


[es(tag=gameClient, REQUIRE=isDrone)]
def drone_enable_input(evt : DroneEnterEvent;
                       eid aka drone_eid : EntityId;
                       playerOwnerEid : EntityId;
                       drone__inputTemplate : string)
  query(playerOwnerEid) <| $ [es] (possessed : EntityId)
    query(possessed) <| $[es(REQUIRE=hero)] ()
      addSubTemplate(drone_eid, drone__inputTemplate)


[es(tag=gameClient, REQUIRE=isDrone, on_event=(DroneLeaveEvent, DroneForceLeaveEvent))]
def drone_disable_input(evt : Event;
                        eid aka drone_eid : EntityId;
                        playerOwnerEid : EntityId;
                        drone__inputTemplate : string)
  query(playerOwnerEid) <| $ [es] (possessed : EntityId)
    query(possessed) <| $[es(REQUIRE=hero)] ()
      removeSubTemplate(drone_eid, drone__inputTemplate)


[es(tag=server, no_order, REQUIRE=isDrone)]
def drone_camera_check_distance(info : ParallelUpdateFrameDelayed;
                                eid aka drone_eid : EntityId;
                                transform aka drone_transform : float3x4;
                                drone__owner : EntityId;
                                drone__coverageArea : float2;
                                drone__interferenceNotificationPause : float;
                                drone__isUnderControl : bool;
                                var drone__enableControl : bool&;
                                var drone__interferenceNotificationNextTime : float&)
  query(drone__owner) <| $ [es] (transform aka owner_transform : float3x4)
    let distSquare = distance_sq(owner_transform[3], drone_transform[3])
    drone__enableControl = distSquare <= square(drone__coverageArea.y)
    if distSquare > square(drone__coverageArea.y) && is_nexus_mode()
      sendEvent(drone_eid, DroneDestroyEvent())
    if !drone__isUnderControl
      return
    if distSquare > square(drone__coverageArea.y)
      send_net_event(drone__owner, ShowStatusTip(statusTip = "status_tip_drone_lost_signal"))
      send_net_event(drone_eid, DroneForceLeaveEvent())
    elif distSquare > square(drone__coverageArea.y) * 0.5f && info.curTime > drone__interferenceNotificationNextTime
      drone__interferenceNotificationNextTime = info.curTime + drone__interferenceNotificationPause
      send_net_event(drone__owner, ShowStatusTip(statusTip = "status_tip_drone_weak_signal"))


[es(tag=server, REQUIRE=isDrone)]
def destroy_drone(evt : DroneDestroyEvent;
                  eid aka drone_eid : EntityId;
                  drone_crash__crashProgressTempl : string;
                  transform aka drone_transform : float3x4;
                  drone__cameraReplicateEid : EntityId;
                  var drone_crash__isCrashed : bool&;
                  var drone__enableControl : bool&;
                  drone_crash__crashTime : float;
                  drone__owner : EntityId;
                  drone_crash__explosionTemplate : string;
                  drone__remoteConsole : EntityId)
  if drone_crash__isCrashed
    return
  drone_crash__isCrashed = true
  drone__enableControl = false
  addSubTemplate(drone_eid, drone_crash__crashProgressTempl) <| $(var init)
    init |> set("game_effect__destroyAt", get_sync_time() + drone_crash__crashTime)
  addSubTemplate(drone__cameraReplicateEid, drone_crash__crashProgressTempl) <| $(var init)
    init |> set("game_effect__destroyAt", get_sync_time() + drone_crash__crashTime)
  var tm = IDENT_TM
  query(drone__owner) <| $ [es] (var drone_deploying__operating : bool&)
    drone_deploying__operating = false
  tm[3] = drone_transform[3]
  createEntity(drone_crash__explosionTemplate) <| $(var init : ComponentsInitializer)
    init |> set("transform", drone_transform)
    init |> set("ownerEid", drone__owner)
  query(drone__remoteConsole) <| $[es] (var drone_remote_console__useAffectEid : EntityId&;
                                        var drone_remote_console__attachedAnimcharEid : EntityId&)
    destroyEntity(drone_remote_console__useAffectEid)
    destroyEntity(drone_remote_console__attachedAnimcharEid)
    drone_remote_console__useAffectEid = INVALID_ENTITY_ID
    drone_remote_console__attachedAnimcharEid = INVALID_ENTITY_ID
  destroyEntity(drone__remoteConsole)


[es(tag=server, track=isAlive, REQUIRE=isDrone)]
def hit_drone_destroy(evt : Event;
                      isAlive : bool;
                      drone__owner : EntityId;
                      eid aka drone_eid : EntityId)
  if !isAlive
    sendEvent(drone_eid, DroneDestroyEvent())
    query(drone__owner) <| $[es] (isAlive : bool)
      if isAlive
        send_net_event(drone__owner, ShowStatusTip(statusTip = "status_tip_drone_destroy"))


def stop_human_from_piloting_drone(human_eid : EntityId)
  find_query() <| $ [es(REQUIRE=isDrone)] (drone__owner : EntityId;
                                           eid aka drone_eid : EntityId)
    if drone__owner == human_eid
      send_net_event(drone_eid, DroneForceLeaveEvent())
      return true
    return false


[es(tag=server, track=(isAlive, isDowned))]
def destroy_drone_on_death_drone_owner(evt : Event;
                                       eid aka human_eid : EntityId;
                                       isAlive : bool;
                                       isDowned : bool)
  if !isAlive || isDowned
    stop_human_from_piloting_drone(human_eid)


[es(tag=server, on_disappear)]
def destroy_drone_on_drone_owner_extracted(evt : Event;
                                           eid aka human_eid : EntityId)
  query(human_eid) <| $[es] (possessedByPlr : EntityId)
    query(possessedByPlr) <| $[es] (scoring_player__isExtractedSuccess : bool)
      if scoring_player__isExtractedSuccess
        stop_human_from_piloting_drone(human_eid)


[es(tag=server)]
def kick_out_of_drone_if_damaged(evt : EventOnEntityHit;
                                 drone__owner : EntityId;
                                 eid aka drone_eid : EntityId)
  if drone__owner == evt.victim
    send_net_event(drone_eid, DroneForceLeaveEvent())


[es(on_appear, REQUIRE=isDrone)]
def camera_and_propeller_anim_on_appear(evt : Event;
                                        var phys_vars : PhysVars;
                                        var drone__propellerVarId : int&;
                                        var drone__cameraPitchVarId : int&)
  drone__propellerVarId = registerVar(phys_vars, "Props_rotation", 0.0)
  drone__cameraPitchVarId = registerVar(phys_vars, "pitch", 0.0)


[es(tag=gameClient, no_order, REQUIRE=isDrone)]
def anim_rotate_camera_and_propeller_nodes(info : ParallelUpdateFrameDelayed;
                                           drone__propellerVarId : int;
                                           drone__cameraPitchVarId : int;
                                           var phys_vars : PhysVars)
  setVar(phys_vars, drone__propellerVarId, info.curTime * 500f)
  query() <| $ [es(REQUIRE=droneCamera)] (camera__vertAngle : float)
    setVar(phys_vars, drone__cameraPitchVarId, -camera__vertAngle)


[es(tag=server, REQUIRE=isDrone, on_event=CmdPostPhysUpdate)]
def drone_recon_apply_volumetric_damage(evt : Event;
                                        eid : EntityId;
                                        drone__immortalAt : float;
                                        drone__collisionDamageMult : float = 0.01f;
                                        helicopter_net_phys : HelicopterActor)
  if drone__immortalAt > get_sync_time()
    return
  var totalDamage = 0.
  for dmg in helicopter_net_phys.phys.volumetricDamageData
    if dmg.reason == DamageReason.DMG_REASON_COLLISION
      totalDamage += dmg.damage * drone__collisionDamageMult

  let pos = float3(helicopter_net_phys.phys.currentState.location.P)

  if totalDamage > 1.
    damage_entity(eid, INVALID_ENTITY_ID/* offender */, DamageDesc(DamageType.DM_COLLISION, totalDamage, pos))


[es(tag=server, on_appear, after=drone_startup, REQUIRE=isDrone)]
def create_remote_console_to_drone(evt : Event;
                                   eid aka drone_eid : EntityId;
                                   drone__owner : EntityId;
                                   drone__remoteConsoleTempl : string;
                                   var drone__remoteConsole : EntityId&)
  drone__remoteConsole = create_item_in_inventory_container(drone__remoteConsoleTempl, drone__owner) <| $(var init : ComponentsInitializer)
    init |> set("drone_remote_console__droneEid", drone_eid)
    init |> set("item__humanOwnerEid", drone__owner)
  send_net_event(drone__owner, ShowStatusTip(statusTip = "status_tip_create_control_console"))


[es(tag=server, track=item__humanOwnerEid, REQUIRE=item_drone_remote_console)]
def change_drone_owner_on_pickup_console(evt : Event;
                                         item__humanOwnerEid : EntityId;
                                         drone_remote_console__droneEid : EntityId)
  query(item__humanOwnerEid) <| $[es] (possessedByPlr : EntityId)
    query(drone_remote_console__droneEid) <| $[es] (var drone__owner : EntityId&;
                                                    var playerOwnerEid : EntityId&)
      drone__owner = item__humanOwnerEid
      playerOwnerEid = possessedByPlr


[es(tag=server, REQUIRE=item_drone_remote_console)]
def use_drone_remote_console(evt : EventOnLootItemUsed;
                             drone_remote_console__droneEid : EntityId;
                             drone_remote_console__useAffectTemplate : string;
                             drone_remote_console__attachedAnimcharTemplate : string;
                             animchar__res : string;
                             var drone_remote_console__useAffectEid : EntityId&;
                             var drone_remote_console__attachedAnimcharEid : EntityId&)
  query(drone_remote_console__droneEid) <| $[es] (var drone__isUnderControl : bool&;
                                                  drone__enableControl : bool;
                                                  drone__owner : EntityId)
    if !drone__enableControl
      send_net_event(drone__owner, ShowStatusTip(statusTip = "status_tip_drone_too_far"))
      return
    drone_remote_console__useAffectEid = createEntity(drone_remote_console__useAffectTemplate) $(init)
      init |> set("game_effect__attachedTo", drone__owner)
    drone_remote_console__attachedAnimcharEid = createEntity(drone_remote_console__attachedAnimcharTemplate) $(init)
      init |> set("slot_attach__attachedTo", drone__owner)
      init |> set("animchar__res", animchar__res)
      init |> set("slot_attach_show_after_appear__time", 0.05)
    send_net_event(drone_remote_console__droneEid, DroneEnterEvent())
    drone__isUnderControl = true


[es(tag=server, REQUIRE=isDrone, on_event=(DroneLeaveEvent, DroneForceLeaveEvent))]
def drone_is_out_of_control(evt : Event;
                            drone__remoteConsole : EntityId;
                            drone__preiodBeforeGrounding : float;
                            var drone__isUnderControlAt : float&;
                            var drone__isUnderControl : bool&)
  drone__isUnderControl = false
  drone__isUnderControlAt = get_sync_time() + drone__preiodBeforeGrounding
  query(drone__remoteConsole) <| $[es] (var drone_remote_console__useAffectEid : EntityId&;
                                        var drone_remote_console__attachedAnimcharEid : EntityId&)
    destroyEntity(drone_remote_console__useAffectEid)
    destroyEntity(drone_remote_console__attachedAnimcharEid)
    drone_remote_console__useAffectEid = INVALID_ENTITY_ID
    drone_remote_console__attachedAnimcharEid = INVALID_ENTITY_ID


[es(REQUIRE=human_inventory, REQUIRE_NOT=deadEntity)]
def human_inventory_pickup_drone(evt : RequestItemPickup; eid : EntityId)
  if !is_hero_can_pickup_items(eid)
    return
  query(evt.itemEid) <| $[es(REQUIRE=isDrone)] ()
    let inventoryContainerEid = get_inventory_for_item(eid, evt.itemEid)
    if inventoryContainerEid == INVALID_ENTITY_ID
      create_status_tip("status_tip_no_inventory_space")


[es(tag=server)]
def start_folding_drone_to_inventory(evt : CmdItemPickup;
                                     eid aka human_eid : EntityId;
                                     var human_net_phys : HumanActor&)
  query(evt.item) <| $[es(REQUIRE=isDrone)] (item__useTime : float;
                                             drone__owner : EntityId)
    if !is_can_pickup_item(human_eid, evt.item) || !is_hero_can_pickup_items(human_eid) || !is_actor_can_move_item(human_eid, evt.item)
      return
    let inventoryContainerEid = get_inventory_for_item(human_eid, evt.item)
    if inventoryContainerEid == INVALID_ENTITY_ID
      send_net_event(drone__owner, ShowStatusTip(statusTip = "status_tip_no_inventory_space"))
      return
    let start_time = get_sync_time()
    let duration = item__useTime
    let droneEid = evt.item
    inventory_item_prepare_using(human_eid, droneEid, droneEid, start_time, duration)
    human_net_phys.phys.currentState |> human_phys_state_set_stoppedSprint(true)
    sendEventImmediate(droneEid, EventOnItemStartUse(userEid = human_eid, targetEid = droneEid))


[es(tag=server, REQUIRE=isDrone)]
def fold_drone_in_inventory(evt : EventOnLootItemUsed;
                            eid aka drone_eid : EntityId;
                            drone__remoteConsole : EntityId;
                            drone__owner : EntityId;
                            drone__createInInvetoryTemplate : string)
  let human_eid = evt.target
  if !is_can_pickup_item(human_eid, drone_eid) || !is_hero_can_pickup_items(human_eid) || !is_actor_can_move_item(human_eid, drone_eid)
    return
  let inventoryContainerEid = get_inventory_for_item(human_eid, drone_eid)
  if inventoryContainerEid == INVALID_ENTITY_ID
    send_net_event(drone__owner, ShowStatusTip(statusTip = "status_tip_no_inventory_space"))
    return
  if drone__owner != human_eid
    send_net_event(drone__owner, ShowStatusTip(statusTip = "status_tip_drone_has_been_captured"))
  query(drone__remoteConsole) <| $[es] (var drone_remote_console__useAffectEid : EntityId&;
                                        var drone_remote_console__attachedAnimcharEid : EntityId&)
    destroyEntity(drone_remote_console__useAffectEid)
    destroyEntity(drone_remote_console__attachedAnimcharEid)
    drone_remote_console__useAffectEid = INVALID_ENTITY_ID
    drone_remote_console__attachedAnimcharEid = INVALID_ENTITY_ID
  destroyEntity(drone__remoteConsole)
  create_item_in_inventory_container(drone__createInInvetoryTemplate, inventoryContainerEid)
  destroyEntity(drone_eid)


[es(tag=server, REQUIRE=isDrone, no_order)]
def drone_grounding_is_under_controll(info : ParallelUpdateFrameDelayed;
                                      drone__isUnderControl : bool;
                                      drone__isUnderControlAt : float;
                                      var helicopter_net_phys : HelicopterActor)
  if drone__isUnderControl
    return
  helicopter_net_phys.phys.producedCT.yaw = 0.0f
  helicopter_net_phys.phys.producedCT.roll = 0.0f
  helicopter_net_phys.phys.producedCT.yaw = 0.0f
  if info.curTime > drone__isUnderControlAt
    helicopter_net_phys.phys.currentState.power = 0.45f


[es(tag=server, REQUIRE=isDrone)]
def drone_drop_grenade(evt : DroneDropGrenade;
                       drone__dropGrenadeTempl : string;
                       drone__owner : EntityId;
                       itemContainer : EidList;
                       transform : float3x4)
  var grenadeItem = INVALID_ENTITY_ID
  for item in itemContainer
    query(item) <| $[es(REQUIRE=item__grenadeType)] ()
      grenadeItem = item
  if grenadeItem == INVALID_ENTITY_ID
    send_net_event(drone__owner, ShowStatusTip(statusTip = "status_tip_drone_doesnt_have_grenade"))
    return
  query(grenadeItem) <| $ [es] (item__shell : string)
    createEntity(drone__dropGrenadeTempl) <| $(init)
      init |> set("transform", transform)
      init |> set("ownerEid", drone__owner)
      init |> set("on_create__spawnActivatedShellBlk", item__shell)
  destroyEntity(grenadeItem)


[es(tag=render, no_order, REQUIRE=input__enabled)]
def drone_areas_quality_distance(info : ParallelUpdateFrameDelayed;
                                 drone__owner : EntityId;
                                 transform aka drone_transform : float3x4;
                                 drone__coverageArea : float2;
                                 drone__connectionQualityWarningDist : float;
                                 var drone__distanceToOperator : float&;
                                 var drone__connectionQuality : int&;
                                 var drone__connectionQualityWarning : bool&)
  query(drone__owner) <| $ [es(REQUIRE=watchedByPlr)] (transform aka owner_transform : float3x4)
    let coverageArea = drone__coverageArea.y
    let partOfCoverage = coverageArea / 3.0
    let dronePos = drone_transform[3]
    let ownerPos = owner_transform[3]
    let distance = length(dronePos - ownerPos)
    drone__distanceToOperator = distance
    drone__connectionQuality = min(3, 3 - int(distance / partOfCoverage))
    drone__connectionQualityWarning = max(coverageArea - distance, 0.0) < drone__connectionQualityWarningDist


[es(tag=server, REQUIRE=isDrone)]
def destroy_drone_on_change_round(evt : EventNexusRoundModeRoundDebriefing;
                                  eid aka drone_eid : EntityId)
  sendEvent(drone_eid, DroneDestroyEvent())


[es(tag=server, REQUIRE=isDrone, no_order)]
def drone_destroy_if_very_low_height(info : ParallelUpdateFrameDelayed;
                                     eid aka drone_eid : EntityId;
                                     drone__owner : EntityId;
                                     helicopter_net_phys : HelicopterActor)
  if float(helicopter_net_phys.phys.currentState.location.P.y) < -95.0
    send_net_event(drone__owner, ShowStatusTip(statusTip = "status_tip_drone_destroy"))
    sendEvent(drone_eid, DroneDestroyEvent())