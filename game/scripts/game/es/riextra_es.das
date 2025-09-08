require ecs
require net
require math.base
require danetlibs.native_dasevents.main.native_events
require game.events.events
require game.events.events_game
require game.events.events_active_matter
require game.es.riextra_common
require game.es.inventory_drop_common
require game.es.grav_zones_common
require RendInst
require RendInstPhys
require DagorMath
require DagorSystem
require Dacoll
require Grid
require level


[es(before=(rendinst_axis_state_es, rendinst_move_es), on_appear, on_event=EventRendinstsLoaded)]
def riextra_create_es(evt : Event;
                      eid : EntityId;
                      ri_extra : RiExtraComponent;
                      var initialTransform : float3x4;
                      var transform : float3x4)
  if riex_isRiGenExtraValid(ri_extra.handle)
    var m : mat44f
    getRIGenExtra44(ri_extra.handle, m)
    initialTransform = float3x4(m)
    transform = initialTransform
  elif get_DAECS_EXTENSIVE_CHECKS() != 0
    logwarn("Rendinst entity {eid}<{getEntityTemplateName(eid)}> has not valid ri handle {ri_extra.handle} on creation. Probably already destroyed.")


[es(tag=dev, track=rendinst_axis_rotation__targetAngle, before=rendinst_axis_state_es)]
def rendinst_axis_state_es_dev(evt : Event;
                               eid : EntityId;
                               transform : float3x4;
                               ri_extra : RiExtraComponent;
                               rendinst_axis_rotation__enabled : Tag const?;
                               rendinst_axis_rotation__targetAngle : float;
                               rendinst_axis_rotation__curAngle : float = 0.0)
  if get_DAECS_EXTENSIVE_CHECKS() != 0
    let enabled = !is_equal_float(rendinst_axis_rotation__curAngle, rendinst_axis_rotation__targetAngle)
    let axisRotationEnabled = rendinst_axis_rotation__enabled != null
    if enabled != axisRotationEnabled
      let pos = transform[3]
      var riTm : mat44f
      let isValid = riex_isRiGenExtraValid(ri_extra.handle)
      if isValid
        getRIGenExtra44(ri_extra.handle, riTm)
      else
        riTm.col3 = float4()
      print("rendinst_axis_state_es_dev {!isValid ? "invalid" : (enabled ? "enable" : "disable")}
            eid={eid} riex.handle={ri_extra.handle} curAngle={rendinst_axis_rotation__curAngle}
            targetAngle={rendinst_axis_rotation__targetAngle} pos={pos} handle_pos={riTm.col3}")


[es(REQUIRE=ri_extra, track=rendinst_axis_rotation__targetAngle, after=riextra_create_es,
  REQUIRE_NOT=rotating_rendinst_simple_phys_processing)]
def rendinst_axis_state_es(evt : Event;
                           eid : EntityId;
                           rendinst_axis_rotation__enabled : Tag const?;
                           rendinst_axis_rotation__targetAngle : float;
                           rendinst_axis_rotation__curAngle : float = 0.0;
                           var rendinst_axis_rotation__startAngle : float?;
                           rendinst_axis_rotation__subTemplate : string)
  let enabled = !is_equal_float(rendinst_axis_rotation__curAngle, rendinst_axis_rotation__targetAngle)
  let axisRotationEnabled = (rendinst_axis_rotation__enabled != null)
  if enabled != axisRotationEnabled
    if enabled
      if rendinst_axis_rotation__startAngle != null
        *rendinst_axis_rotation__startAngle = rendinst_axis_rotation__curAngle
      addSubTemplate(eid, rendinst_axis_rotation__subTemplate)
    else
      removeSubTemplate(eid, rendinst_axis_rotation__subTemplate)


[es(before=rendinst_move_es, after=riextra_create_es, on_appear, on_event=EventRendinstsLoaded)]
def rendinst_axis_force_initial_rotation_es(evt : Event;
                                            ri_extra : RiExtraComponent;
                                            rendinst_axis_rotation__targetAngle : float;
                                            rendinst_axis_rotation__axis : float3;
                                            initialTransform : float3x4;
                                            var transform : float3x4;
                                            var rendinst_axis_rotation__curAngle : float&)
  if riex_isRiGenExtraValid(ri_extra.handle)
    rendinst_axis_rotation__curAngle = rendinst_axis_rotation__targetAngle
    var tm : float3x4
    make_tm(rendinst_axis_rotation__axis, deg_to_rad(rendinst_axis_rotation__targetAngle), tm)
    transform = initialTransform * tm


[es(REQUIRE=rendinst_axis_rotation__enabled, no_order)]
def rendinst_axis_rotation_es(info : UpdateStageInfoAct;
                              eid : EntityId;
                              rendinst_axis_rotation__axis : float3;
                              rendinst_axis_rotation__rotSpeed : float;
                              rendinst_axis_rotation__rotSpeedKoef : float = 1.0;
                              rendinst_axis_rotation__pauseOnCollision : bool = false;
                              rendinst_axis_rotation__stopOnCollision : bool = false;
                              rendinst_axis_rotation__stopOnCollisionDelay : float = 0.0;
                              rendinst_axis_rotation__subTemplate : string;
                              initialTransform : float3x4;
                              ri_extra : RiExtraComponent;
                              var transform : float3x4;
                              var rendinst_axis_rotation__targetAngle : float&;
                              var rendinst_axis_rotation__curAngle : float&;
                              var rendinst_axis_rotation__collisionStartedAt : float?)
  assume rotSpeed = rendinst_axis_rotation__rotSpeed
  assume rotSpeedKoef = rendinst_axis_rotation__rotSpeedKoef
  assume collisionStartedAt = rendinst_axis_rotation__collisionStartedAt
  assume stopOnCollisionDelay = rendinst_axis_rotation__stopOnCollisionDelay

  if !is_equal_float(rendinst_axis_rotation__curAngle, rendinst_axis_rotation__targetAngle)
    let newAngle = move_to(rendinst_axis_rotation__curAngle,
                             rendinst_axis_rotation__targetAngle, info.dt, rotSpeed * rotSpeedKoef)
    var rotTm : float3x4
    make_tm(rendinst_axis_rotation__axis, deg_to_rad(newAngle), rotTm)
    let newTrans = initialTransform * rotTm

    using(ri_extra.handle) <| $(var desc : RendInstDesc#)
      if rendinst_axis_rotation__pauseOnCollision || rendinst_axis_rotation__stopOnCollision
        if check_ri_collision_filtered(desc, transform, newTrans, int(PhysLayer.EPL_KINEMATIC))

          if collisionStartedAt != null && *collisionStartedAt == 0.0
            *collisionStartedAt = info.curTime // Collision started

          if rendinst_axis_rotation__stopOnCollision

            if stopOnCollisionDelay > 0.0 && collisionStartedAt != null
              if info.curTime - *collisionStartedAt < stopOnCollisionDelay
                return

            //Don't stop on client because the collided physobj may be rolled back later, but targetAngle won't
            //It is important to have a way to sync rendinst_axis_rotation__targetAngle if it __stopOnCollision=true
            if is_server()
              rendinst_axis_rotation__targetAngle = rendinst_axis_rotation__curAngle
              sendEvent(eid, EventRiRotationPrematureStop())
          return

      rendinst_axis_rotation__curAngle = newAngle
      transform = newTrans

  if !is_equal_float(rendinst_axis_rotation__curAngle, rendinst_axis_rotation__targetAngle)
    return

  if collisionStartedAt != null
    *collisionStartedAt = 0.0

  rendinst_axis_rotation__curAngle = rendinst_axis_rotation__targetAngle // make sure that floats are binary equal
  if riex_isRiGenExtraValid(ri_extra.handle)
    move_ri_extra_tm(ri_extra.handle, transform)

  if get_DAECS_EXTENSIVE_CHECKS() != 0
    print("rendinst_axis_rotation_es disable eid={eid} riex.handle={ri_extra.handle} curAngle={rendinst_axis_rotation__curAngle}
          targetAngle={rendinst_axis_rotation__targetAngle} pos={transform[3]}")

  sendEvent(eid, EventRendinstRotationFinished())
  removeSubTemplate(eid, rendinst_axis_rotation__subTemplate) // target angle reached - disable this ES


[es(REQUIRE=rendinst_phys_move__enabled, after=after_net_phys_sync)]
def rendinst_phys_move_es(evt : UpdateStageInfoAct;
                          ri_extra : RiExtraComponent;
                          transform : float3x4)
  if riex_isRiGenExtraValid(ri_extra.handle)
    move_ri_extra_tm(ri_extra.handle, transform)


[es(REQUIRE=rendinst_axis_rotation_damped_oscillations_on_rotation_finished)]
def rendinst_rotation_damped_oscillations_start(evt : EventRendinstRotationFinished;
                                                eid : EntityId;
                                                var rendinst_axis_rotation__damped_oscillations__t : float&)
  rendinst_axis_rotation__damped_oscillations__t = 0.0
  addSubTemplate(eid, "rendinst_axis_rotation_damped_oscillations_enabled")

[es(REQUIRE=rendinst_axis_rotation__damped_oscillations__enabled, no_order)]
def rendinst_rotation_damped_oscillations_update(info : UpdateStageInfoAct;
                                                 eid : EntityId;
                                                 rendinst_axis_rotation__damped_oscillations__amplitude : float;
                                                 rendinst_axis_rotation__damped_oscillations__decayRate : float;
                                                 rendinst_axis_rotation__damped_oscillations__frequency : float;
                                                 rendinst_axis_rotation__curAngle : float;
                                                 rendinst_axis_rotation__axis : float3;
                                                 initialTransform : float3x4;
                                                 var transform : float3x4;
                                                 var rendinst_axis_rotation__damped_oscillations__t : float&)
  assume t = rendinst_axis_rotation__damped_oscillations__t
  assume amplitude = rendinst_axis_rotation__damped_oscillations__amplitude
  assume decayRate = rendinst_axis_rotation__damped_oscillations__decayRate
  assume frequency = rendinst_axis_rotation__damped_oscillations__frequency

  t += info.dt
  var dampedOscillationAngle = amplitude * exp(-decayRate * t) * cos(frequency * t)
  if abs(dampedOscillationAngle) < 1e-5
    dampedOscillationAngle = 0.0
    removeSubTemplate(eid, "rendinst_axis_rotation_damped_oscillations_enabled")
  let newAngle = rendinst_axis_rotation__curAngle + dampedOscillationAngle
  var rotTm : float3x4
  make_tm(rendinst_axis_rotation__axis, deg_to_rad(newAngle), rotTm)
  let newTrans = initialTransform * rotTm
  transform = newTrans


[es(REQUIRE=rendinst_axis_rotation_braking_way_on_rotation_finished)]
def rendinst_rotation_braking_way_start(evt : EventRendinstRotationFinished;
                                        eid : EntityId;
                                        rendinst_axis_rotation__startAngle : float;
                                        rendinst_axis_rotation__curAngle : float;
                                        rendinst_axis_rotation__braking_way__allowedDir : float;
                                        var rendinst_axis_rotation__braking_way__t : float&;
                                        var rendinst_axis_rotation__braking_way__dir : float&)
  let dir = sign(rendinst_axis_rotation__curAngle - rendinst_axis_rotation__startAngle)
  if rendinst_axis_rotation__braking_way__allowedDir != 0.0
    if sign(rendinst_axis_rotation__braking_way__allowedDir) != dir
      return

  rendinst_axis_rotation__braking_way__t = 0.0
  rendinst_axis_rotation__braking_way__dir = dir
  addSubTemplate(eid, "rendinst_axis_rotation_braking_way_enabled")


[es(REQUIRE=rendinst_axis_rotation__braking_way__enabled, no_order)]
def rendinst_rotation_braking_way_update(info : UpdateStageInfoAct;
                                         eid : EntityId;
                                         rendinst_axis_rotation__braking_way__decayRate : float;
                                         rendinst_axis_rotation__rotSpeed : float;
                                         rendinst_axis_rotation__axis : float3;
                                         rendinst_axis_rotation__braking_way__dir : float;
                                         initialTransform : float3x4;
                                         var transform : float3x4;
                                         var rendinst_axis_rotation__curAngle : float&;
                                         var rendinst_axis_rotation__braking_way__t : float&)
  assume t = rendinst_axis_rotation__braking_way__t
  assume decayRate = rendinst_axis_rotation__braking_way__decayRate

  t += info.dt
  var rotSpeed = rendinst_axis_rotation__rotSpeed * exp(-decayRate * t)
  if rotSpeed < 1e-5
    rotSpeed = 0.0
    removeSubTemplate(eid, "rendinst_axis_rotation_braking_way_enabled")
    return

  let newAngle = rendinst_axis_rotation__curAngle + rotSpeed * rendinst_axis_rotation__braking_way__dir * info.dt
  var rotTm : float3x4
  make_tm(rendinst_axis_rotation__axis, deg_to_rad(newAngle), rotTm)
  let newTrans = initialTransform * rotTm
  rendinst_axis_rotation__curAngle = newAngle
  transform = newTrans


[es]
def replace_ri_extra_cmd(evt : CmdReplaceRiExtraRes;
                         eid : EntityId;
                         var ri_extra__handle : uint64?;
                         var ri_extra__name : das_string?)
  if evt.addPrevRiToRestorables && !evt.destroyPrevRi
    logerr("{eid}<{getEntityTemplateName(eid)}>: CmdReplaceRiExtraRes addPrevRiToRestorables is 'true', but destroyPrevRi is 'false' - this is not supported.")

  replace_ri_extra_res(
    eid, evt.riExtra,
    evt.destroyPrevRi,
    evt.addPrevRiToRestorables,
    evt.createPrevRiDestr)

  if ri_extra__handle != null
    *ri_extra__handle = RIEX_HANDLE_NULL
  if ri_extra__name != null
    *ri_extra__name := evt.riExtra


[es(REQUIRE=ri_preload__preloadOnLevelLoaded, on_event=EventLevelLoaded, on_appear)]
def start_resource_preload(evt : Event;
                           eid : EntityId)
  if is_level_loaded()
    eid |> addSubTemplate("rendinst_resource_preload")


[es(on_appear, on_event=EventRendinstsLoaded, after=rendinst_move_es,
  REQUIRE_NOT=ri_extra_loading)]
def check_ri_extra_loading_needed(evt : Event; eid : EntityId; ri_extra : RiExtraComponent)
  if !riex_isRiGenExtraValid(ri_extra.handle)
    eid |> addSubTemplate("ri_extra_loading")


[es(REQUIRE=ri_extra_loading, no_order)]
def update_ri_extra_bbox_on_load(act : UpdateStageInfoAct;
                                 eid : EntityId;
                                 ri_extra : RiExtraComponent;
                                 var ri_extra__bboxMin : float3&;
                                 var ri_extra__bboxMax : float3&)
  if riex_isRiGenExtraValid(ri_extra.handle)
    let bbox = getRIGenBBox(RendInstDesc(ri_extra.handle))
    ri_extra__bboxMin = bbox.boxMin
    ri_extra__bboxMax = bbox.boxMax
    eid |> removeSubTemplate("ri_extra_loading")
    sendEvent(eid, EventRiExtraLoaded())


[es(on_appear)]
def ri_after_destruction_init(evt : Event;
                              ri_extra__riAfterDestruction : string;
                              var ri_preload__name : das_string)
  ri_preload__name := ri_extra__riAfterDestruction


[es(tag=server)]
def ri_extra_after_destruction(evt : EventOnRendinstDestruction;
                               eid : EntityId;
                               ri_extra__riAfterDestruction : string;
                               var ri_extra__riAfterDestructionTriggered : bool&)
  if ri_extra__riAfterDestructionTriggered
    return

  ri_extra__riAfterDestructionTriggered = true

  send_net_event(eid, CmdReplaceRiExtraRes(
    riExtra := ri_extra__riAfterDestruction,
    destroyPrevRi = true,
    addPrevRiToRestorables = true,
    createPrevRiDestr = false))


[es(tag=server)]
def drop_items_on_ri_destruction(evt : EventRendinstDestroyed)

  if !is_level_loaded()
    return

  let upDir = -get_grav_dir(evt.riTm[3], true)
  let destrRendinstDot = dot(evt.riTm[3], upDir)

  var bbox = evt.riBBox
  bbox |> bbox3_inflate(0.16) // Magic margin number from ri_collision_check_margin
  bbox = evt.riTm * bbox
  for_each_entity_in_grid(ecs_hash("loot"), bbox, GridEntCheck.BOUNDING) <| $(item_eid : EntityId)
    query(item_eid) <| $ [es(REQUIRE=item__dropOnRiDestroy)] (item__recreateInWorldPhys : das_string const?;
                                                              var transform aka item_transform : float3x4)
      let overDestroyedRendinst = destrRendinstDot < dot(item_transform[3], upDir)
      if overDestroyedRendinst
        if item__recreateInWorldPhys != null && !empty(*item__recreateInWorldPhys)
          sendEvent(item_eid, CmdStartItemInWorldPhys())
        else
          drop_item_on_ground(item_transform)
          send_net_event(item_eid, CmdUpdateTransform(tm = item_transform))