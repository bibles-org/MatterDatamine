require ecs
require AnimV20
require DngHuman
require DngPhysObj
require game.es.grav_zones_common
require game.events.events_active_matter
require PhysDecl
require DagorMath
require game.events.events
require game.events.events_game
require RiDestr
require CollRes
require DngActor
require DagorSystem

def get_phys_pivot_pos(location : Loc; local_phys_pos : float3)
  var locationTm : float3x4
  location_toTM(location, locationTm)
  return locationTm * local_phys_pos


[es(on_appear, track=transform)]
def track_grav_zone_transform(evt : Event; transform : float3x4; var grav_zone__itm : float3x4&; var grav_zone__precalcScale : float3&)
  grav_zone__itm = inverse(transform)
  grav_zone__precalcScale = float3(length(transform[0]), length(transform[1]), length(transform[2]))


[es(before=before_net_phys_sync, REQUIRE=grav_zones_affected, REQUIRE_NOT=grav_zones_immunity, REQUIRE_NOT=disableUpdate)]
def gather_human_grav_dir(info : CmdPostPhysUpdate;
                          var human_net_phys : HumanActor&)
  assume phys = human_net_phys.phys
  let physPos = get_phys_pivot_pos(phys.currentState.location, phys.gravityPivot)
  human_net_phys.phys.currentState.gravDirection = get_grav_dir(physPos, true)


[es(tag=netClient, after=(after_net_phys_sync), REQUIRE=grav_zones_affected, REQUIRE_NOT=(grav_zones_immunity, disableUpdate))]
def remote_shadow_gather_human_grav_dir(info : ParallelUpdateFrameDelayed;
                                        var human_net_phys : HumanActor&)
  if human_net_phys.role == NetRole.ROLE_REMOTELY_CONTROLLED_SHADOW
    assume phys = human_net_phys.phys
    let physPos = get_phys_pivot_pos(phys.currentState.location, phys.gravityPivot)
    assume state = human_net_phys.phys.currentState
    state.gravDirection = get_grav_dir(physPos, true)
    state.vertDirection = -state.gravDirection


[es(tag=gameClient, REQUIRE=grav_zones_affected)]
def set_fastphys_grav_dir(evt : ParallelUpdateFrameDelayed;
                          var animchar : AnimcharBaseComponent;
                          human_net_phys : HumanActor)
  assume phys = human_net_phys.phys
  let physPos = get_phys_pivot_pos(phys.currentState.location, phys.gravityPivot)
  let gravDir = get_grav_dir(physPos, true)
  animchar |> animchar_setFastPhysSystemGravityDirection(gravDir)


[es(before=before_net_phys_sync, REQUIRE=grav_zones_affected, REQUIRE_NOT=disableUpdate)]
def gather_physobj_grav_dir(info : CmdPostPhysUpdate; var phys_obj_net_phys : PhysObjActor&; collres : CollisionResource const?)
  assume phys = phys_obj_net_phys.phys
  let boxCenter = collres != null ? BBox3(collres.vFullBBox).center : float3(.0, 0.1, .0)
  let physPos = get_phys_pivot_pos(phys.currentState.location, boxCenter)
  phys.currentState.gravDirection = get_grav_dir(physPos, true)


[es(no_order)]
def destructable_objects_grav_dir(info : ParallelUpdateFrameDelayed; level__gameObjectsEntitiesCreated : bool)
  if !level__gameObjectsEntitiesCreated
    return
  get_destructable_objects() <| $(objects)
    for obj in objects
      if obj == null
        continue
      var physSys = get_phys_sys_instance(*obj)
      if physSys == null
        continue
      for i in range(physSys.bodyCount)
        var physBody = phys_system_instance_getBody(*physSys, i)
        if physBody == null
          return
        set_grav_for_phys_body(info.dt, physBody)


[es(tag=gameClient, no_order, REQUIRE=grav_zones_affected)]
def footprints_grav_dir(info : ParallelUpdateFrameDelayed;
                        human_net_phys : HumanActor;
                        footstep__heightOffset : float;
                        var footstep__offset : float3&)
  assume phys = human_net_phys.phys
  let physPos = get_phys_pivot_pos(phys.currentState.location, phys.gravityPivot)
  footstep__offset = -get_grav_dir(physPos, true) * footstep__heightOffset


[es(tag=server, on_appear)]
def grav_zone_create_visual(evt : Event;
                            transform : float3x4;
                            grav_zone__visualTempl : string;
                            var grav_zone__visualEid : EntityId&)
  grav_zone__visualEid = createEntity(grav_zone__visualTempl) <| $(init)
    set(init, "transform", transform)

[es(tag=server, on_disappear)]
def grav_zone_destroy_visual(evt : Event;
                             grav_zone__visualEid : EntityId)
  destroyEntity(grav_zone__visualEid)


[es(tag=server, on_appear, REQUIRE=grav_zone__type, REQUIRE_NOT=grav_zone__lateCreationAllowed)]
def logerr_when_zone_created_after_dir_requested(evt : Event; eid : EntityId; transform : float3x4)
  find_query() <| $ [es] (level__gravDirRequested : bool)
    if level__gravDirRequested
      logerr("Grav zone created after some get_grav_dir were made. <{eid}>{{getEntityTemplateName(eid)}}. at [{transform[3]}]. grav dir requests must be delayed until this zone is created (most likely solution). Alternatively, to disable this error either add 'grav_zone__lateCreationAllowed' tag or pass 'allow_premature_calls' flag to the early get_grav_dir requests.")
    return true


def max_axis(vec : float3)
  return max(max(vec.x, vec.y), vec.z)


[es(on_appear, on_event=CmdUpdateGridScale, track=transform, REQUIRE=transform,
    after=(grid_obj_init_tm_scale_es, track_grav_zone_transform), before=grid_obj_update_es)]
def gravity_zone_init_scale_sphere(evt : Event;
                                   grav_zone__outerRadius : float;
                                   grav_zone__precalcScale : float3;
                                   var grid_obj__fixedTmScale : float&)
  grid_obj__fixedTmScale = 2f * max_axis(grav_zone__precalcScale * grav_zone__outerRadius)


[es(on_appear, on_event=CmdUpdateGridScale, track=transform, REQUIRE=transform,
    after=(grid_obj_init_tm_scale_es, track_grav_zone_transform), before=grid_obj_update_es)]
def gravity_zone_init_scale_box(evt : Event;
                                gravity_zone__boxSize : float3;
                                grav_zone__precalcScale : float3;
                                var grid_obj__fixedTmScale : float&)
  grid_obj__fixedTmScale = sqrt(2f) * max_axis(grav_zone__precalcScale * gravity_zone__boxSize)


[es(on_appear, on_event=CmdUpdateGridScale, track=transform, REQUIRE=transform,
    after=(grid_obj_init_tm_scale_es, track_grav_zone_transform), before=grid_obj_update_es)]
def gravity_zone_init_scale_cylinder(evt : Event;
                                     grav_zone__length : float;
                                     grav_zone__radius : float;
                                     grav_zone__precalcScale : float3;
                                     var grid_obj__fixedTmScale : float&)
  grid_obj__fixedTmScale = max_axis(grav_zone__precalcScale * float3(2f * grav_zone__radius, 2f * grav_zone__radius, grav_zone__length))