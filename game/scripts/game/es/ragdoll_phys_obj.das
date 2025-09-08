require ecs
require GeomNodeTree
require AnimV20
require DagorMath
require game.events.events_game
require game.events.events_active_matter
require game.es.ecs_common
require game.es.grav_zones_common
require PhysDecl
require app
require game.events.events
require DngPhysObj
require DngHuman
require Dacoll
require CollRes
require DagorSystem
require Grid
require PhysObj
require AnimV20


let
  POS_HEIGHT_OFFSET_FOR_PHYS_OBJ = 0.4


def private make_phys_obj(owner_eid : EntityId;
                          template_name : string;
                          tm : float3x4)
  return createEntity(template_name) <| $(var init)
    set(init, "transform", tm)
    set(init, "ragdoll_phys_obj__attachedTo", owner_eid)


[es(tag=server, on_appear, REQUIRE=deadEntity)]
def creation_ragdoll_phys_obj_human_net_phys(evt : Event;
                                             eid : EntityId;
                                             animchar : AnimcharBaseComponent;
                                             transform : float3x4;
                                             human_net_phys__locationPos : DPoint3;
                                             human_net_phys : HumanActor;
                                             net_ragdoll__physObjTemplate : string;
                                             net_ragdoll__animcharNodeForCreationPositionName : string = "";
                                             var ragdoll_phys_obj__physObjEid : EntityId&)
  var tm = transform
  tm[3] = float3(human_net_phys__locationPos) - human_net_phys.phys.currentState.gravDirection * POS_HEIGHT_OFFSET_FOR_PHYS_OBJ
  if net_ragdoll__animcharNodeForCreationPositionName != ""
    let nodeIdx = *animchar.nodeTree |> geomtree_findNodeIndex(net_ragdoll__animcharNodeForCreationPositionName)
    if nodeIdx >= 0
      tm[3] = *animchar.nodeTree |> geomtree_getNodeWpos(nodeIdx) - human_net_phys.phys.currentState.gravDirection * 1e-2
    else
      logerr("{get_entity_info(eid)}: ragdoll phys obj was trying to be created at node '{net_ragdoll__animcharNodeForCreationPositionName}', but it was not found in animchar")
  if tm[3].y <= get_DESTROY_ENTITY_FLOOR_Y()
    logerr("{get_entity_info(eid)}: ragdoll y is below DESTROY_ENTITY_FLOOR_Y!
pos={tm[3]}, transform={transform}, human_net_phys__locationPos={human_net_phys__locationPos}, gravDirection={human_net_phys.phys.currentState.gravDirection}")
  ragdoll_phys_obj__physObjEid = make_phys_obj(eid, net_ragdoll__physObjTemplate, tm)


[es(tag=server, on_appear, REQUIRE=deadEntity, REQUIRE_NOT=(human_net_phys__locationPos))]
def creation_ragdoll_phys_obj_from_transform(evt : Event;
                                             eid : EntityId;
                                             transform : float3x4;
                                             net_ragdoll__physObjTemplate : string;
                                             var ragdoll_phys_obj__physObjEid : EntityId&)
  var tm = transform
  tm[3] = tm[3] + tm[1] * POS_HEIGHT_OFFSET_FOR_PHYS_OBJ
  if tm[3].y <= get_DESTROY_ENTITY_FLOOR_Y()
    logerr("{get_entity_info(eid)}: ragdoll y is below DESTROY_ENTITY_FLOOR_Y!
pos={tm[3]}, transform={transform}")
  ragdoll_phys_obj__physObjEid = make_phys_obj(eid, net_ragdoll__physObjTemplate, tm)


[es(tag=server)]
def switch_ragdoll_physobj(evt : EventSwitchRagdollPhysobj;
                           eid : EntityId;
                           transform : float3x4;
                           var ragdoll_phys_obj__physObjEid : EntityId&)
  destroyEntity(ragdoll_phys_obj__physObjEid)
  ragdoll_phys_obj__physObjEid = make_phys_obj(eid, evt.templateName, transform)


[es(tag=server, on_disappear)]
def destroy_ragdoll_phys_obj_on_human_disappear(evt : Event; var ragdoll_phys_obj__physObjEid : EntityId&)
  destroyEntity(ragdoll_phys_obj__physObjEid)
  ragdoll_phys_obj__physObjEid = INVALID_ENTITY_ID

[es(tag=server, track=isAlive)]
def destroy_ragdoll_phys_obj_on_resurrection(evt : Event;
                                             isAlive : bool;
                                             var ragdoll_phys_obj__physObjEid : EntityId&)
  if isAlive
    destroyEntity(ragdoll_phys_obj__physObjEid)
    ragdoll_phys_obj__physObjEid = INVALID_ENTITY_ID


[es(tag=server)]
def save_projectile_impulse_on_server(evt : EventOnPhysImpulse;
                                      var server_projectile_impulse : ProjectileImpulse;
                                      projectile_impulse__impulseSaveDeltaTime = 1f)
  let curTime = evt.atTime
  let collNodeId = evt.nodeId
  let pos = evt.pos
  let impulse = evt.impulse
  save_projectile_impulse(curTime, server_projectile_impulse, collNodeId, pos, impulse, projectile_impulse__impulseSaveDeltaTime)


[es(tag=server, on_appear)]
def apply_projectile_impulse_on_ragdoll_phys_obj(evt : Event;
                                                 eid : EntityId;
                                                 ragdoll_phys_obj__maxImpulseLength : float;
                                                 ragdoll_phys_obj__impulseMult : float;
                                                 ragdoll_phys_obj__attachedTo : EntityId)
  let curTime = get_sync_time()
  var impulse = float3(0f)
  query(ragdoll_phys_obj__attachedTo) <| $ [es] (server_projectile_impulse : ProjectileImpulse;
                                                 projectile_impulse__impulseSaveDeltaTime = 0.3f)
    projectile_impulse_get_data(server_projectile_impulse) <| $(var pairs)
      for pair in pairs
        if pair.time < curTime - projectile_impulse__impulseSaveDeltaTime
          continue
        impulse += pair.data.impulse * ragdoll_phys_obj__impulseMult
  if length(impulse) > ragdoll_phys_obj__maxImpulseLength
    impulse = normalize(impulse) * ragdoll_phys_obj__maxImpulseLength
  sendEvent(eid, CmdPushPhys(vel = impulse))


[es(tag=server)]
def awake_ragdoll_phys_obj_when_rendinst_destroyed_nearby(evt : EventRendinstDestroyed)
  var bbox = evt.riBBox
  let margin = 0.5f
  bbox |> bbox3_inflate(margin)
  bbox = evt.riTm * bbox
  for_each_entity_in_grid(ecs_hash("interactable"), bbox, GridEntCheck.BOUNDING) <| $(eid : EntityId)
    query(eid) <| $ [es(REQUIRE=(disableUpdate, ragdoll_phys_obj__attachedTo))] (var phys_obj_net_phys : PhysObjActor)
      if phys_obj_net_phys.phys.currentState.isSleep
        phys_obj_net_phys.phys |> wakeUp()


[es(tag=server, on_appear, REQUIRE=militant_ragdoll_phys_obj)]
def transfer_am_to_ragdoll(evt : Event; ragdoll_phys_obj__attachedTo : EntityId; var am_storage__value aka ragdoll_am_storage__value : int&)
  query(ragdoll_phys_obj__attachedTo) <| $ [es] (var am_storage__value aka militant_am_storage__value : int&)
    ragdoll_am_storage__value = militant_am_storage__value
    militant_am_storage__value = 0
