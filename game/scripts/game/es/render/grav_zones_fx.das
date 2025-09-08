require ecs
require fx
require PhysDecl
require game.es.grav_zones_common
require DagorMath
require game.es.camera_common
require game.events.events_active_matter


[cpp_event(broadcast)]
struct StartEffectEvent
  pos : float3
  fx : AcesEffect?
  fxType : int


[es(tag=render)]
def fx_grav_zone_init(evt : StartEffectEvent)
  if are_grav_zones_loaded()
    let gravityTm = float3x3(get_grav_tm(evt.pos, true))
    deref(evt.fx) |> setGravityTm(gravityTm)


[es(tag=render, track=transform, on_event=EventGravityZonesLoaded)]
def fx_grav_zone_move_effect(evt : Event; transform : float3x4; var effect : TheEffect&)
  if are_grav_zones_loaded()
    let gravityTm = float3x3(get_grav_tm(transform[3], true))
    effect |> effect_set_gravity_tm(gravityTm)


[es(tag=render, on_appear, on_disappear, REQUIRE=(grav_zone__type, transform), track=transform)]
def fx_grav_zone_change_grav_zone(evt : Event)
  if are_grav_zones_loaded()
    query() <| $ [es] (transform : float3x4; var effect : TheEffect&)
      let gravityTm = float3x3(get_grav_tm(transform[3], true))
      effect |> effect_set_gravity_tm(gravityTm)

  change_grav_zone_list(get_cam_itm()[3])


[es(tag=render, no_order)]
def fx_update_grav_zone_buffer(evt : UpdateStageInfoAct;
                               var dafg_gravity_zone__camera_pos_last : float3&;
                               dafg_gravity_zone__camera_pos_threshold : float)
  let cameraPos = get_cam_itm()[3]

  if length_sq(cameraPos - dafg_gravity_zone__camera_pos_last) >= dafg_gravity_zone__camera_pos_threshold
    dafg_gravity_zone__camera_pos_last = cameraPos
    change_grav_zone_list(cameraPos)


enum GravityZoneShape
  GRAVITY_ZONE_SHAPE_SPHERE = 0
  GRAVITY_ZONE_SHAPE_BOX
  GRAVITY_ZONE_SHAPE_CYLINDER


def change_grav_zone_list(camera_pos : float3)
  using() <| $(var gravity_zone_buffer : GravityZoneBuffer)
    query() <| $ [es] (transform : float3x4;
                       grav_zone__outerRadius : float;
                       grav_zone__innerRadius : float;
                       grav_zone__type : int;
                       grav_zone__weight : float;
                       grav_zone__isImportant : bool)
      let size = float3(safeinv(grav_zone__innerRadius - grav_zone__outerRadius), safediv(-grav_zone__outerRadius, grav_zone__innerRadius - grav_zone__outerRadius), grav_zone__outerRadius * grav_zone__outerRadius)
      gravity_zone_buffer |> push(transform, size, uint(GravityZoneShape.GRAVITY_ZONE_SHAPE_SPHERE), uint(grav_zone__type), grav_zone__weight, length_sq(camera_pos - transform[3]), grav_zone__isImportant)

    query() <| $ [es] (transform : float3x4;
                       gravity_zone__boxSize : float3;
                       grav_zone__type : int;
                       grav_zone__weight : float;
                       grav_zone__isImportant : bool)
      let size = 0.5 * gravity_zone__boxSize
      gravity_zone_buffer |> push(transform, size, uint(GravityZoneShape.GRAVITY_ZONE_SHAPE_BOX), uint(grav_zone__type), grav_zone__weight, length_sq(camera_pos - transform[3]), grav_zone__isImportant)

    query() <| $ [es] (transform : float3x4;
                       grav_zone__length, grav_zone__radius : float;
                       grav_zone__type : int;
                       grav_zone__weight : float;
                       grav_zone__isImportant : bool)
      let size = float3(grav_zone__length, grav_zone__radius * grav_zone__radius, 0.0)
      gravity_zone_buffer |> push(transform, size, uint(GravityZoneShape.GRAVITY_ZONE_SHAPE_CYLINDER), uint(grav_zone__type), grav_zone__weight, length_sq(camera_pos - transform[3]), grav_zone__isImportant)

    acesfx_set_gravity_zones(gravity_zone_buffer)


[es(tag=render, before=start_async_phys_sim_es,
    REQUIRE_NOT=disableUpdate, REQUIRE=deadEntity, before=ragdoll_sync)]
def ragdoll_grav_dir(evt : ParallelUpdateFrameDelayed;
                     var ragdoll : PhysRagdoll)
  var physSys = ragdoll_getPhysSys(ragdoll)
  if physSys == null
    return
  for i in range(physSys.bodyCount)
    var physBody = phys_system_instance_getBody(*physSys, i)
    if physBody == null
      return
    set_grav_for_phys_body(evt.dt, physBody)
