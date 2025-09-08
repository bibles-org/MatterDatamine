require ecs
require DngNet
require game.events.events
require game.events.events_game
require game.events.inventory_events
require game.events.events_active_matter
require game.utils.team
require Dacoll
require DagorMath
require CollRes
require PhysMat

def destroy_point(eid : ecs::EntityId; target : ecs::EntityId)
  destroyEntity(eid)
  let countPtr = get_int(target, "countUserMark")
  if countPtr == null
    return
  let count = deref(countPtr)
  if count < 1
    removeSubTemplate(target, "user_point_entities_tracker")
  else
    set(target, "countUserMark", count - 1)

[es(tag=server, no_order, REQUIRE_NOT=map_user_point_infinite)]
def map_user_point_timer_es(info : ParallelUpdateFrameDelayed;
                            eid : ecs::EntityId;
                            timer__destroy : float;
                            target : ecs::EntityId = INVALID_ENTITY_ID)
  if info.curTime > timer__destroy
    destroy_point(eid, target)


[es(tag=server, on_event=CmdDeleteMapUserPoint)]
def destroy_map_user_point_es(evt : Event;
                              eid : ecs::EntityId;
                              target : EntityId = INVALID_ENTITY_ID)
  destroy_point(eid, target)


[es(tag=server)]
def clear_all_map_user_point_es(evt : CmdClearAllAttachedUserPoint;
                                eid : ecs::EntityId;
                                target : ecs::EntityId;
                                team : int)
  if is_teams_friendly(team, evt.team)
    if target == evt.target
      destroy_point(eid, target)

[es(tag=gameClient)]
def on_cmd_create_map_point(evt : CmdCreateMapPoint; eid : EntityId; possessed : EntityId)
  let len = 500.0
  let x = evt.x
  let z = evt.z
  let xz = float2(x, z)
  var upmostPos = float3(x, traceht_lmesh(xz) + len, z)
  let traceDir = float3(0.0, -1.0, 0.0)
  var norm : float3
  var t = len * 2.
  var pmid : int
  var rendInstDesc = RendInstDesc()
  var aimRayMatId = PHYSMAT_INVALID
  query(possessed) <| $ [es] (human_weap__currentGunEid : EntityId)
    query(human_weap__currentGunEid) <| $ [es] (gun__aimRayMatId : int)
      aimRayMatId = gun__aimRayMatId

  traceray_normalized(upmostPos, traceDir, t, pmid, norm, ETF_DEFAULT, rendInstDesc, aimRayMatId)
  upmostPos.y = t >= 0.0 ? upmostPos.y - t : 0.0
  send_net_event(eid, CmdCreateMapUserPoint(pos = upmostPos, norm = norm, item_name = "main"))

[es(tag=server)]
def clear_attached_points_es(evt : EventOnItemPickup; team : int)
  let itemEid = evt.itemEid
  if itemEid |> has("userPointTracker")
    broadcastEvent(CmdClearAllAttachedUserPoint(target = itemEid, team = team))
    removeSubTemplate(itemEid, "user_point_entities_tracker")

[es(tag=gameClient, no_order, REQUIRE_NOT=userPointVehicleOffset)]
def userpoint_update_vehicle_marker_position(act : ParallelUpdateFrameDelayed; userPointVehicleTargetEid : EntityId; var transform aka userpoint_transform : float3x4&)
  query(userPointVehicleTargetEid) <| $ [es(REQUIRE=vehicle)] (transform : float3x4; collres : CollisionResource)
    userpoint_transform[3] = transform * BBox3(collres.vFullBBox).center

[es(tag=gameClient, no_order)]
def userpoint_update_point_on_vehicle_marker_position(act : ParallelUpdateFrameDelayed;
                                                      userPointVehicleTargetEid : EntityId;
                                                      var transform aka userpoint_transform : float3x4&;
                                                      userPointVehicleOffset : float3)
  query(userPointVehicleTargetEid) <| $ [es(REQUIRE=vehicle)] (transform : float3x4)
    userpoint_transform[3] = transform * userPointVehicleOffset
