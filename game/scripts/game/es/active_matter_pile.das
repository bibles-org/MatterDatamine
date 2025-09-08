require ecs
require ecs.safe
require DagorMath
require math.base
require AnimV20
require app
require DagorRandom
require Dacoll
require strings
require daslib/strings_boost
require DagorSystem
require game.utils.hero
require math.random
require PhysDecl
require game.es.grav_zones_common
require game.events.events_active_matter
require game.events.events
require GeomNodeTree


def private determine_animchar_by_count(animchars : Array; count : int; animchar_by_default : string) : string
  if count == 0
    return animchar_by_default
  for animchar in animchars
    let obj = get_ecs_object(animchar)
    if obj == null
      continue
    let countRnd = get_IPoint2(obj, "countRnd") ?? int2()
    let res = get_string(obj, "animchar_res", "")
    if count >= countRnd.x && count <= countRnd.y
      return res
  logerr("could not find animchar for am with count {count}")
  return animchar_by_default


def private determine_scale_by_count(animchars : Array; count : int; min_scale : float) : float
  for animchar in animchars
    let obj = get_ecs_object(animchar)
    if obj == null
      continue
    let countRnd = get_IPoint2(obj, "countRnd") ?? int2()
    if count >= countRnd.x && count <= countRnd.y
      return cvt(float(count), float(countRnd.x), float(countRnd.y), min_scale, 1f)
  return 1f


def private determine_prev_animchar(animchars : Array; count : int) : string
  var prevAnimchar : string
  for animchar in animchars
    let obj = get_ecs_object(animchar)
    if obj == null
      continue
    let countRnd = get_IPoint2(obj, "countRnd") ?? int2()
    if count >= countRnd.x && count <= countRnd.y
      return prevAnimchar
    prevAnimchar = get_string(obj, "animchar_res", "")
  return prevAnimchar


def private make_visual_item_entity(tmpl : string; owner_eid : EntityId; tm : float3x4; salt : float; animchar : string; is_sleeping : bool) : EntityId
  return createEntity(tmpl) <| $(var init)
    set(init, "am_pile_visual__attachedTo", owner_eid)
    set(init, "transform", tm)
    set(init, "am_pile_visual__originalTransform", tm)
    set(init, "am_pile_visual__sleep", is_sleeping)
    set(init, "animchar__res", animchar)
    set(init, "am_pile_visual__salt", salt)
    set(init, "animchar_render__enabled", !is_sleeping)
    set(init, "animchar__updatable", !is_sleeping)


def private make_emission_field_effects(tmpl : string; transform : float3x4)
  createEntity(tmpl) <| $(var init)
    set(init, "transform", transform)


[es(tag=gameClient, on_appear)]
def creation_am_visual(evt : Event;
                       eid : EntityId;
                       transform : float3x4;
                       animchar__res : string;
                       item__count : int;
                       am_pile__visualItemPosOffset : float3;
                       active_matter_pile__lightTemplate : string;
                       active_matter_pile__visualTemplate : string;
                       am_pile__visualItemAxisMaxAngle : float;
                       @shared_comp active_matter_pile__animchars : Array;
                       var active_matter_pile__lightEid : EntityId&;
                       var active_matter_pile__visualEid : EntityId&;
                       var active_matter_pile__sleepingVisualEid : EntityId&)
  // on appear we create 2 visual entities: one for sleeping state and one for awake state
  // sleeping visual entity is created with animchar of previous count
  let salt = rnd_float(0f, TWOPI)
  var tm = transform
  tm[3] = transform * am_pile__visualItemPosOffset
  var quat = DagorMath::quat(transform)
  var rotQ : quat
  euler_to_quat(0f, rnd_float(-am_pile__visualItemAxisMaxAngle, am_pile__visualItemAxisMaxAngle) * DEG_TO_RAD,
    rnd_float(-am_pile__visualItemAxisMaxAngle, am_pile__visualItemAxisMaxAngle) * DEG_TO_RAD, rotQ)
  quat = quat * rotQ
  make_tm(quat, tm[3], tm)

  make_emission_field_effects("am_emission_field_distortion", tm)
  make_emission_field_effects("am_emission_field_flare", tm)
  make_emission_field_effects("am_emission_field_glare", tm)

  assume visualEid = active_matter_pile__visualEid
  assume animchars = active_matter_pile__animchars
  visualEid = make_visual_item_entity(active_matter_pile__visualTemplate,
                                      eid,
                                      tm,
                                      salt,
                                      determine_animchar_by_count(animchars, item__count, animchar__res),
                                      false)
  active_matter_pile__lightEid = createEntity(active_matter_pile__lightTemplate) <| $(var init)
    init |> set("transform", tm)

  let prevAnimchar = determine_prev_animchar(animchars, item__count)
  // if there is no previous animchar, then we don't need to create sleeping visual entity
  if !empty(prevAnimchar)
    assume sleepingVisualEid = active_matter_pile__sleepingVisualEid
    sleepingVisualEid = make_visual_item_entity(active_matter_pile__visualTemplate, eid, tm, salt, prevAnimchar, true)


[es(tag=gameClient, track=transform)]
def update_am_visual_transform(evt : Event;
                               am_pile__visualItemPosOffset : float3;
                               transform aka item_transform : float3x4;
                               active_matter_pile__lightEid : EntityId;
                               active_matter_pile__visualEid : EntityId;
                               active_matter_pile__sleepingVisualEid : EntityId)
  query(active_matter_pile__lightEid) <| $ [es] (var transform : float3x4)
    var tm = item_transform
    tm[3] += am_pile__visualItemPosOffset
    transform = tm
  query(active_matter_pile__visualEid) <| $ [es] (var am_pile_visual__originalTransform : float3x4)
    var tm = item_transform
    tm[3] = item_transform * am_pile__visualItemPosOffset
    am_pile_visual__originalTransform = tm
  query(active_matter_pile__sleepingVisualEid) <| $ [es] (var am_pile_visual__originalTransform : float3x4)
    var tm = item_transform
    tm[3] = item_transform * am_pile__visualItemPosOffset
    am_pile_visual__originalTransform = tm


def destroy_am_visual(visual_eid : EntityId)
  query(visual_eid) <| $ [es] (var animchar_render__enabled : bool&)
    animchar_render__enabled = false
    addSubTemplate(visual_eid, "am_pile_visual_destroying")


[es(tag=gameClient, no_order)]
def am_pile_visual_destroying_update(act : ParallelUpdateFrameDelayed;
                                     eid : EntityId;
                                     am_pile_visual_destroying__speed : float;
                                     var am_pile_visual__scaleMult : float&)
  if am_pile_visual__scaleMult <= 0.0
    destroyEntity(eid)
  // Destroying at next frame for applying zero scale to the effect
  am_pile_visual__scaleMult = max(0.0, am_pile_visual__scaleMult - am_pile_visual_destroying__speed * act.dt)


[es(tag=gameClient, on_disappear)]
def destroying_am_visual(evt : Event;
                         active_matter_pile__lightEid : EntityId;
                         active_matter_pile__visualEid : EntityId;
                         active_matter_pile__sleepingVisualEid : EntityId)
  destroyEntity(active_matter_pile__lightEid)
  destroy_am_visual(active_matter_pile__visualEid)
  destroy_am_visual(active_matter_pile__sleepingVisualEid)


[es(tag=gameClient, on_appear)]
def am_visual_set_start_scale_start_at(evt : Event;
                                       am_pile_visual__startScaleDelay : float;
                                       var am_pile_visual__startScaleStartAt : float&)
  am_pile_visual__startScaleStartAt = get_sync_time() + am_pile_visual__startScaleDelay


[es(tag=gameClient, after=animchar_before_render_es)]
def am_visual_phys(info : ParallelUpdateFrameDelayed;
                   am_pile_visual__salt : float;
                   am_pile_visual__originalTransform : float3x4;
                   am_pile_visual__verticalMoveFrequency : float;
                   am_pile_visual__verticalMoveAltitude : float;
                   am_pile_visual__rotationFrequency : float;
                   am_pile_visual__rotationFrequencyDrift : float;
                   am_pile_visual__rotationFrequencyDriftSpeed : float;
                   am_pile_visual__rotationFrequencyAdd : float;
                   am_pile_visual__scale : float;
                   am_pile_visual__scaleMult : float;
                   am_pile_visual__sleepScale : float;
                   am_pile_visual__precessionCurAngle : float;
                   am_pile_visual__startScaleSpeed : float;
                   am_pile_visual__startScaleStartAt : float;
                   animchar__visible : bool;
                   var am_pile_visual__startScaleMult : float&;
                   var am_pile_visual__curRotAngle : float&;
                   var am_pile_visual__rotationFrequencyCurDrift : float&;
                   var transform : float3x4&)
  if !animchar__visible
    return
  // rotation
  assume salt = am_pile_visual__salt
  assume rotationFrequency = am_pile_visual__rotationFrequency
  assume rotationFrequencyDrift = am_pile_visual__rotationFrequencyDrift
  assume rotationFrequencyCurDrift = am_pile_visual__rotationFrequencyCurDrift
  assume rotationFrequencyDriftSpeed = am_pile_visual__rotationFrequencyDriftSpeed
  assume rotationFrequencyAdd = am_pile_visual__rotationFrequencyAdd
  assume angle = am_pile_visual__curRotAngle
  assume startScaleMult = am_pile_visual__startScaleMult

  rotationFrequencyCurDrift = (sin((info.curTime + salt) * rotationFrequencyDriftSpeed) + 1f) * rotationFrequencyDrift / 2f
  angle += (rotationFrequency + rotationFrequencyCurDrift + rotationFrequencyAdd) * TWOPI * info.dt
  transform = am_pile_visual__originalTransform
  var tm = am_pile_visual__originalTransform
  rotyTM(angle, tm)
  transform = transform * tm
  rotzTM(am_pile_visual__precessionCurAngle * DEG_TO_RAD, tm)
  transform = transform * tm

  if info.curTime > am_pile_visual__startScaleStartAt
    startScaleMult = move_to_scalar(startScaleMult, 1f, info.dt, am_pile_visual__startScaleSpeed)

  // pulsation
  let scale = am_pile_visual__scale * am_pile_visual__scaleMult * am_pile_visual__sleepScale * startScaleMult
  transform[0] = normalize(transform[0]) * float3(scale)
  transform[1] = normalize(transform[1]) * float3(scale)
  transform[2] = normalize(transform[2]) * float3(scale)

  // vertical movement
  assume verticalMoveFrequency = am_pile_visual__verticalMoveFrequency
  assume verticalMoveAltitude = am_pile_visual__verticalMoveAltitude
  let sinusoid = sin((info.curTime + salt) * verticalMoveFrequency * TWOPI) * verticalMoveAltitude
  let levitationOffset = transform[1] * sinusoid
  transform[3] = am_pile_visual__originalTransform[3] + levitationOffset


[es(tag=server, on_appear)]
def am_shell_move_down_effect_appear(evt : Event; am_shell_move_down_effect__timer : float;
                                     var am_shell_move_down_effect__timerEndAt : float&)
  am_shell_move_down_effect__timerEndAt = get_sync_time() + am_shell_move_down_effect__timer


[es(no_order)]
def am_shell_core_companion_act(info : ParallelUpdateFrameDelayed; am_shell_move_down_effect__timerEndAt : float;
                                shell_free_fall_effect__fallOn : float3; var transform : float3x4&;
                                var am_core_companion__parent : EntityId&)
  if info.curTime > am_shell_move_down_effect__timerEndAt
    am_core_companion__parent = INVALID_ENTITY_ID
    transform[3] = move_to(transform[3], shell_free_fall_effect__fallOn, info.dt, 5f)


[es(tag=gameClient, no_order)]
def am_visual_reset_influence_from_gather(info : ParallelUpdateFrameDelayed;
                                          var am_pile_visual__influenceFromGatherers : Point3List&)
  am_pile_visual__influenceFromGatherers |> clear()


[es(tag=render, on_appear)]
def attach_am_pile_use_hint_to_node(evt : Event;
                                    am_pile_attached_to_corpse__corpseEid : EntityId;
                                    var item_world_marker__attachedToEid : EntityId&)
  query(am_pile_attached_to_corpse__corpseEid) <| $ [es] (ragdoll_phys_obj__attachedTo : EntityId)
    item_world_marker__attachedToEid = ragdoll_phys_obj__attachedTo


[es(tag=gameClient, after=resources_gatherer_work_client)]
def am_visual_orient_influence_from_gather(info : ParallelUpdateFrameDelayed;
                                           transform aka am_visual_transform : float3x4;
                                           am_pile_visual__influenceFromGatherers : Point3List;
                                           am_pile_visual__influenceEffectName : string;
                                           var am_pile_visual__influenceFromGatherersEffects : EidList;
                                           am_pile_attached_to_corpse__corpseEid = INVALID_ENTITY_ID)
  let effectsLen = length(am_pile_visual__influenceFromGatherersEffects)
  let gathererLen = length(am_pile_visual__influenceFromGatherers)
  let eraseCount = effectsLen - gathererLen
  if eraseCount > 0
    let erasePos = effectsLen - eraseCount
    for i in range(erasePos, effectsLen)
      destroyEntity(am_pile_visual__influenceFromGatherersEffects[i])
    am_pile_visual__influenceFromGatherersEffects |> erase(erasePos, eraseCount)

  var am_transform = am_visual_transform

  // If the AM is inside the body, take the position of the node to which the physobj is attached
  query(am_pile_attached_to_corpse__corpseEid) <| $ [es] (ragdoll_phys_obj__attachedTo : EntityId;
                                                          ragdoll_phys_obj__links : Array)
    query(ragdoll_phys_obj__attachedTo) <| $ [es] (animchar : AnimcharBaseComponent)
      var targetNodeName : string
      for link in ragdoll_phys_obj__links
        let obj = get_ecs_object(link)
        if obj == null
          continue
        targetNodeName = get_string(obj, "nodeName", "")
        if get_bool(obj, "root") ?? false
          break
      if empty(targetNodeName)
        return
      let nodeId = geomtree_findNodeIndex(*animchar.nodeTree, targetNodeName)
      am_transform[3] = geomtree_getNodeWpos(*animchar.nodeTree, nodeId)

  for j in iter_range(am_pile_visual__influenceFromGatherers)
    assume influencePos = am_pile_visual__influenceFromGatherers[j]
    if j >= effectsLen
      let effectEid = createEntity(am_pile_visual__influenceEffectName) <| $(var init)
        var tm = IDENT_TM
        tm[3] = am_transform[3]
        set(init, "active_matter_gather_effect__pilePos", am_transform[3])
        set(init, "active_matter_gather_effect__gatherPos", influencePos)
        set(init, "transform", tm)
      am_pile_visual__influenceFromGatherersEffects |> push(effectEid)
    else
      query(am_pile_visual__influenceFromGatherersEffects[j]) <| $ [es] (var active_matter_gather_effect__pilePos : float3&;
                                                                         var active_matter_gather_effect__gatherPos : float3&)
        active_matter_gather_effect__pilePos = am_transform[3]
        active_matter_gather_effect__gatherPos = influencePos


[es(tag=gameClient, no_order)]
def update_active_matter_gather_effect(update : ParallelUpdateFrameDelayed;
                                       active_matter_gather_effect__flySpeed : float;
                                       active_matter_gather_effect__pilePos : float3;
                                       active_matter_gather_effect__gatherPos : float3;
                                       active_matter_gather_effect__requiredDistanceToTarget : float;
                                       var transform : float3x4&)
  let dir = active_matter_gather_effect__gatherPos - transform[3]
  let len = length(dir)
  if len < active_matter_gather_effect__requiredDistanceToTarget
    transform[3] = active_matter_gather_effect__pilePos
    return

  let speed = active_matter_gather_effect__flySpeed * update.dt
  let move = min(speed, len) * dir / len
  transform[3] += move


[es(tag=gameClient, on_disappear)]
def am_visual_destroy_influence_from_gather(evt : Event;
                                            var am_pile_visual__influenceFromGatherersEffects : EidList)
  for effectEid in am_pile_visual__influenceFromGatherersEffects
    destroyEntity(effectEid)
  am_pile_visual__influenceFromGatherersEffects |> clear()


[es(tag=gameClient, no_order)]
def am_visual_anim_act(info : ParallelUpdateFrameDelayed;
                       am_pile_visual__salt : float;
                       am_pile_visual__influenceFromGatherers : Point3List;
                       am_pile_visual__gatherRotationFreqMult : float;
                       am_pile_visual__gatherRotationFreqChangeTime : float;
                       am_pile_visual__gatherPulsationInOutTime : float2;
                       am_pile_visual__gatherPulsationMult : float;
                       am_pile_visual__precessionMaxAngle : float;
                       am_pile_visual__precessionTime : float;
                       am_pile_visual__precessionOscillationAngle : float;
                       am_pile_visual__precessionOscillationSpeed : float;
                       var am_pile_visual__scale : float&;
                       var am_pile_visual__rotInStateStep : float&;
                       var am_pile_visual__rotOutStateStep : float&;
                       var am_pile_visual__pulsInStateStep : float&;
                       var am_pile_visual__pulsOutStateStep : float&;
                       var am_pile_visual__rotationFrequencyAdd : float&;
                       var am_pile_visual__precessionCurAngle : float&;
                       var am_pile_visual__precessionOscillationCurAngle : float&)
  assume salt = am_pile_visual__salt
  assume rotationFrequencyAdd = am_pile_visual__rotationFrequencyAdd
  assume gatherRotationFreqMult = am_pile_visual__gatherRotationFreqMult
  assume rotInStateStep = am_pile_visual__rotInStateStep
  assume rotOutStateStep = am_pile_visual__rotOutStateStep
  assume pulsInStateStep = am_pile_visual__pulsInStateStep
  assume pulsOutStateStep = am_pile_visual__pulsOutStateStep
  assume gatherRotationFreqChangeTime = am_pile_visual__gatherRotationFreqChangeTime
  assume gatherPulsationMult = am_pile_visual__gatherPulsationMult
  assume scale = am_pile_visual__scale
  assume gatherPulsationInOutTime = am_pile_visual__gatherPulsationInOutTime
  assume precessionCurAngle = am_pile_visual__precessionCurAngle
  assume precessionMaxAngle = am_pile_visual__precessionMaxAngle
  assume precessionTime = am_pile_visual__precessionTime
  assume precessionOscillationAngle = am_pile_visual__precessionOscillationAngle
  assume precessionOscillationCurAngle = am_pile_visual__precessionOscillationCurAngle
  assume precessionOscillationSpeed = am_pile_visual__precessionOscillationSpeed


  precessionOscillationCurAngle = cos((info.curTime + salt) * precessionOscillationSpeed) * precessionOscillationAngle

  if length(am_pile_visual__influenceFromGatherers) > 0
    precessionCurAngle = move_to_scalar(precessionOscillationCurAngle, precessionMaxAngle, info.dt, precessionMaxAngle / precessionTime)

    // easeOutSine function for rotation
    rotationFrequencyAdd = min(gatherRotationFreqMult, sin(rotInStateStep * HALF_PI) * gatherRotationFreqMult)
    rotInStateStep = min(1f, rotInStateStep + cvt(info.dt, 0f, gatherRotationFreqChangeTime, 0f, 1f))
    rotOutStateStep = 0f

    // pulsation anim
    if pulsInStateStep >= 1f && pulsOutStateStep >= 1f
      pulsOutStateStep = 0f
      pulsInStateStep = 0f

    // easeInExpo function for pulsation
    if pulsInStateStep < 1f
      scale = cvt((is_equal_float(pulsInStateStep, 0f) ? 0f : pow(2f, 10f * pulsInStateStep - 10f) * gatherPulsationMult),
        0f, gatherPulsationMult, 1f, gatherPulsationMult)
      pulsInStateStep = min(1f, pulsInStateStep + cvt(info.dt, 0f, gatherPulsationInOutTime.x, 0f, 1f))
      pulsOutStateStep = 0f
    else
      scale = cvt(min(gatherPulsationMult, sin(pulsOutStateStep * HALF_PI) * gatherPulsationMult), 0f, gatherPulsationMult, gatherPulsationMult, 1f)
      pulsOutStateStep = min(1f, pulsOutStateStep + cvt(info.dt, 0f, gatherPulsationInOutTime.y, 0f, 1f))

  else
    precessionCurAngle = move_to_scalar(precessionOscillationCurAngle, 0f, info.dt, precessionMaxAngle / precessionTime)

    // easeInSine function for rotation
    rotationFrequencyAdd = cvt(max(0f, (1f - cos(rotOutStateStep * HALF_PI)) * gatherRotationFreqMult), 0f, gatherRotationFreqMult, 1f, 0f)
    rotOutStateStep = min(1f, rotOutStateStep + cvt(info.dt, 0f, gatherRotationFreqChangeTime, 0f, 1f))
    rotInStateStep = 0f

    // easeOutSine function for pulstation
    pulsInStateStep = 0f
    scale = cvt(min(gatherPulsationMult, sin(pulsOutStateStep * HALF_PI) * gatherPulsationMult), 0f, gatherPulsationMult, scale, 1f)
    pulsOutStateStep = min(1f, pulsOutStateStep + cvt(info.dt, 0f, gatherPulsationInOutTime.y, 0f, 1f))


[es(tag=gameClient, track=item__count)]
def change_am_visual_set_scale_and_swap_visuals(evt : Event;
                                                item__count : int;
                                                @shared_comp active_matter_pile__animchars : Array;
                                                var active_matter_pile__sleepingVisualEid : EntityId&;
                                                var active_matter_pile__visualEid : EntityId&)
  assume visualEid = active_matter_pile__visualEid
  query(visualEid) <| $ [es] (animchar__res : string;
                              am_pile_visual__effectsTemplate : string;
                              am_pile_visual__minScaleProc : float;
                              var am_pile_visual__scaleMult : float&;
                              var am_pile_visual__sleep : bool&;
                              var am_pile_visual__effectsDisabled : bool&)
    am_pile_visual__scaleMult = determine_scale_by_count(active_matter_pile__animchars, item__count, am_pile_visual__minScaleProc)

    let newAnimchar = determine_animchar_by_count(active_matter_pile__animchars, item__count, animchar__res)
    // if animchar is not changed, then do nothing
    // else swap sleeping and active visual entities
    if newAnimchar == animchar__res
      return

    am_pile_visual__sleep = true
    removeSubTemplate(visualEid, am_pile_visual__effectsTemplate)
    am_pile_visual__effectsDisabled = true

    query(active_matter_pile__sleepingVisualEid) <| $ [es] (var am_pile_visual__sleep : bool&;
                                                            var animchar_render__enabled : bool&;
                                                            var animchar__updatable : bool&)
      am_pile_visual__sleep = false
      animchar__updatable = true
      animchar_render__enabled = true

    let tmp = active_matter_pile__visualEid
    active_matter_pile__visualEid = active_matter_pile__sleepingVisualEid
    active_matter_pile__sleepingVisualEid = tmp


[es(tag=gameClient, before=am_visual_phys)]
def am_visual_sleep_act(info : ParallelUpdateFrameDelayed;
                        am_pile_visual__sleep : bool;
                        am_pile_visual__sleepWishScale : float;
                        am_pile_visual__sleepScaleSpeed : float;
                        var am_pile_visual__sleepScale : float&)
  let wishScale = am_pile_visual__sleep ? am_pile_visual__sleepWishScale : 1f
  am_pile_visual__sleepScale = move_to(am_pile_visual__sleepScale, wishScale, info.dt, am_pile_visual__sleepScaleSpeed)


[es(tag=gameClient, track=am_pile_visual__sleep)]
def am_visual_track_sleep(evt : Event;
                          am_pile_visual__sleep : bool;
                          am_pile_visual__changeAnimcharTimeDuration : float;
                          var am_pile_visual__changeAnimcharTime : float&)
  if am_pile_visual__sleep
    am_pile_visual__changeAnimcharTime = get_sync_time() + am_pile_visual__changeAnimcharTimeDuration


[es(tag=gameClient, no_order)]
def am_visual_track_change_animchar(info : ParallelUpdateFrameDelayed;
                                    eid : EntityId;
                                    transform : float3x4;
                                    am_pile_visual__salt : float;
                                    am_pile_visual__rotInStateStep : float;
                                    am_pile_visual__rotOutStateStep : float;
                                    am_pile_visual__curRotAngle : float;
                                    am_pile_visual__pulsInStateStep : float;
                                    am_pile_visual__pulsOutStateStep : float;
                                    am_pile_visual__scale : float;
                                    am_pile_visual__originalTransform : float3x4;
                                    am_pile_visual__attachedTo : EntityId;
                                    am_pile_visual__changeAnimcharTime : float)
  if am_pile_visual__changeAnimcharTime > 0f && info.curTime > am_pile_visual__changeAnimcharTime
    query(am_pile_visual__attachedTo) <| $ [es] (active_matter_pile__visualTemplate : string;
                                                 @shared_comp active_matter_pile__animchars : Array;
                                                 item__count : int;
                                                 var active_matter_pile__sleepingVisualEid : EntityId&)
      let prevAnimchar = determine_prev_animchar(active_matter_pile__animchars, item__count)
      // if there is no previous animchar, then we don't need to create sleeping visual entity
      if empty(prevAnimchar)
        return
      active_matter_pile__sleepingVisualEid = createEntity(active_matter_pile__visualTemplate) <| $(var init)
        set(init, "transform", transform)
        set(init, "animchar__res", prevAnimchar)
        set(init, "am_pile_visual__originalTransform", am_pile_visual__originalTransform)
        set(init, "am_pile_visual__salt", am_pile_visual__salt)
        set(init, "am_pile_visual__rotInStateStep", am_pile_visual__rotInStateStep)
        set(init, "am_pile_visual__rotOutStateStep", am_pile_visual__rotOutStateStep)
        set(init, "am_pile_visual__curRotAngle", am_pile_visual__curRotAngle)
        set(init, "am_pile_visual__pulsInStateStep", am_pile_visual__pulsInStateStep)
        set(init, "am_pile_visual__pulsOutStateStep", am_pile_visual__pulsOutStateStep)
        set(init, "am_pile_visual__scale", am_pile_visual__scale)
        set(init, "am_pile_visual__attachedTo", am_pile_visual__attachedTo)
        set(init, "am_pile_visual__sleep", true)
        set(init, "animchar_render__enabled", false)
        set(init, "animchar__updatable", false)
    destroyEntity(eid)


[es(tag=gameClient, no_order)]
def am_pile_visual_effects_distance_optimization(info : ParallelUpdateFrameDelayed;
                                                 eid : EntityId;
                                                 transform aka am_transform : float3x4;
                                                 am_pile_visual__effectsTemplate : string;
                                                 am_pile_visual__renderRadius : float;
                                                 am_pile_visual__nextCheckRenderTimeDuration : float;
                                                 am_pile_visual__sleep : bool;
                                                 var am_pile_visual__effectsDisabled : bool&;
                                                 var am_pile_visual__nextCheckRenderTime : float&)
  if am_pile_visual__sleep || info.curTime < am_pile_visual__nextCheckRenderTime
    return
  am_pile_visual__nextCheckRenderTime = info.curTime + am_pile_visual__nextCheckRenderTimeDuration
  let watchedHeroEid = get_watched_entity()
  query(watchedHeroEid) <| $ [es] (transform : float3x4)
    let dist = distance(transform[3], am_transform[3])
    if dist > am_pile_visual__renderRadius && !am_pile_visual__effectsDisabled
      removeSubTemplate(eid, am_pile_visual__effectsTemplate)
      am_pile_visual__effectsDisabled = true
    elif dist < am_pile_visual__renderRadius && am_pile_visual__effectsDisabled
      addSubTemplate(eid, am_pile_visual__effectsTemplate)
      am_pile_visual__effectsDisabled = false


[es(tag=server, on_appear, REQUIRE=item__am)]
def am_pile_create_emission_field(evt : Event;
                                  eid : EntityId;
                                  active_matter_pile__emissionFieldTemplate : das_string)
  createEntity(string(active_matter_pile__emissionFieldTemplate)) <| $(var init)
    set(init, "am_emission_field__ownerEid", eid)


[es(on_disappear)]
def unlock_am_pile_on_field_disappearing(evt : Event; am_emission_field__ownerEid : EntityId)
  query(am_emission_field__ownerEid) <| $ [es] (var active_matter_pile__locked : bool&)
    active_matter_pile__locked = false


[es(tag=gameClient, no_order)]
def am_pile_emission_field_anim(info : ParallelUpdateFrameDelayed;
                                game_effect__timeToDestroy : float;
                                am_emmision_field__scaleRng : float2;
                                am_emission_field__ownerEid : EntityId;
                                var am_emission_field__wishScaleMult : float&;
                                var transform aka field_transform : float3x4&;
                                var am_emission_field__scaleMult : float&)
  if am_emission_field__scaleMult >= am_emmision_field__scaleRng.x
    am_emission_field__wishScaleMult = am_emmision_field__scaleRng.y

  am_emission_field__scaleMult = move_to_scalar(am_emission_field__scaleMult, am_emission_field__wishScaleMult,
    info.dt, 1f / game_effect__timeToDestroy * 2f)

  field_transform[0] = normalize(field_transform[0]) * am_emission_field__scaleMult
  field_transform[1] = normalize(field_transform[1]) * am_emission_field__scaleMult
  field_transform[2] = normalize(field_transform[2]) * am_emission_field__scaleMult

  query(am_emission_field__ownerEid) <| $ [es] (active_matter_pile__visualEid : EntityId)
    query(active_matter_pile__visualEid) <| $ [es] (transform : float3x4)
      field_transform[3] = transform[3]


[es(tag=server, on_appear, REQUIRE=deadEntity, after=(creation_ragdoll_phys_obj_from_transform, creation_ragdoll_phys_obj_human_net_phys))]
def create_attached_to_corpse_am_pile(evt : Event;
                                      eid : EntityId;
                                      corpse_am__templateForCreation : string;
                                      ragdoll_phys_obj__physObjEid : EntityId)
  createEntity(corpse_am__templateForCreation) <| $(var init : ComponentsInitializer)
    set(init, "am_pile_attached_to_corpse__corpseEid", ragdoll_phys_obj__physObjEid)
    set(init, "item__lastContainerOwnerEid", eid)
  sendEvent(eid, EventAmAttachedToCorpse())


[es(tag=server, on_appear, REQUIRE=deadEntity, after=(creation_ragdoll_phys_obj_from_transform, creation_ragdoll_phys_obj_human_net_phys))]
def create_attached_to_corpse_am_pile_from_am_storage(evt : Event;
                                                      eid : EntityId;
                                                      corpse_am__amStorageToAttachedPile : string;
                                                      ragdoll_phys_obj__physObjEid : EntityId;
                                                      var am_storage__value : int&)
  if am_storage__value <= 0 || corpse_am__amStorageToAttachedPile == ""
    return

  createEntity(corpse_am__amStorageToAttachedPile) <| $(var init : ComponentsInitializer)
    set(init, "am_pile_attached_to_corpse__corpseEid", ragdoll_phys_obj__physObjEid)
    set(init, "item__lastContainerOwnerEid", eid)
    set(init, "item__count", am_storage__value)
  am_storage__value = 0
  sendEvent(eid, EventAmAttachedToCorpse())


[es(tag=server, on_disappear, REQUIRE=ragdoll_phys_obj__attachedTo)]
def destroy_attached_am_pile_on_corpse_disappearing(evt : Event; eid aka corpse_eid : EntityId)
  query() <| $ [es] (eid aka am_eid : EntityId; am_pile_attached_to_corpse__corpseEid : EntityId)
    if am_pile_attached_to_corpse__corpseEid == corpse_eid
      destroyEntity(am_eid)


[es(no_order)]
def set_transform_for_am_pile_attached_to_corpse(info : ParallelUpdateFrameDelayed;
                                                 am_pile_attached_to_corpse__corpseEid : EntityId;
                                                 var transform aka am_transform : float3x4&)
  query(am_pile_attached_to_corpse__corpseEid) <| $ [es] (transform : float3x4)
    am_transform = transform


[es(tag=gameClient, on_disappear, REQUIRE=am_pile_attached_to_corpse__corpseEid)]
def am_pile_attached_to_corpse_disappear(evt : Event;
                                         item__lastContainerOwnerEid : EntityId)
  sendEvent(item__lastContainerOwnerEid, EventAmDrainedFromCorpse())


[es(on_disappear, REQUIRE=am_pile_attached_to_corpse__corpseEid)]
def allow_body_cleanup_on_am_pile_attached_to_corpse_disappear(evt : Event; item__lastContainerOwnerEid : EntityId)
  query(item__lastContainerOwnerEid) <| $ [es] (var bodyCleanupTime : float&; am_inside_body__emptyBodyCleanupTime : float)
    bodyCleanupTime = am_inside_body__emptyBodyCleanupTime
    sendEvent(item__lastContainerOwnerEid, CmdBodyCleanupUpdateTtl(time = bodyCleanupTime))


[es(tag=server, on_disappear)]
def drop_random_entity_on_disappear(evt : Event;
                                    transform : float3x4;
                                    spawn_random_entity_on_disappear__templates : Array;
                                    spawn_random_entity_on_disappear__chance : float)
  if gfrnd() <= spawn_random_entity_on_disappear__chance

    var totalWeight = 0.0
    for data in spawn_random_entity_on_disappear__templates
      totalWeight += (data as Object)?.weight ?? 0.0

    if totalWeight > 0.0
      let rnd = gfrnd() * totalWeight

      var weight = 0.0
      for data in spawn_random_entity_on_disappear__templates
        let templateObj = data as Object
        weight += templateObj?.weight ?? 0.0
        if weight >= rnd
          createEntity(templateObj?["template"] ?? "") <| $(var init : ComponentsInitializer)
            var tm = IDENT_TM
            tm[3] = transform[3]
            init |> set("transform", tm)
          break


[es(tag=server, on_appear)]
def attach_am_to_obj_on_appear(evt : Event;
                               eid : EntityId;
                               transform : float3x4;
                               attach_am_to_obj_on_appear__template : string;
                               attach_am_to_obj_on_appear__count : int2)
  createEntity(attach_am_to_obj_on_appear__template) <| $(var init : ComponentsInitializer)
    set(init, "am_pile_attached_to_obj__objEid", eid)
    set(init, "transform", transform)
    set(init, "item__count", rnd_int(attach_am_to_obj_on_appear__count))


[es(no_order)]
def set_transform_for_am_pile_attached_to_obj(info : ParallelUpdateFrameDelayed;
                                              am_pile_attached_to_obj__objEid : EntityId;
                                              var transform aka am_transform : float3x4&)
  query(am_pile_attached_to_obj__objEid) <| $ [es] (transform : float3x4)
    am_transform = transform


[es(on_disappear, REQUIRE=am_pile_attached_to_obj__objEid)]
def am_pile_attached_to_obj_disappear(evt : Event;
                                      item__lastContainerOwnerEid : EntityId)
  sendEvent(item__lastContainerOwnerEid, EventAmDrainedFromCorpse())


[es(tag=server, on_disappear, REQUIRE=attach_am_to_obj_on_appear__template)]
def obj_with_attached_am_pile_disappear(evt : Event;
                                        eid aka obj_eid : EntityId)
  find_query() <| $ [es] (eid aka am_eid : EntityId; am_pile_attached_to_obj__objEid : EntityId)
    if am_pile_attached_to_obj__objEid == obj_eid
      destroyEntity(am_eid)
      return true
    return false