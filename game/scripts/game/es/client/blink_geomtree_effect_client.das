require ecs
require ecs.soa_template
require fx
require math.base
require game.events.events_active_matter
require game.es.tweening_common
require DagorSystem
require DagorMath
require game.es.game_effect_geomtree_common
require AnimV20
require GeomNodeTree
require CapsuleApproximation


[es(tag=gameClient, on_appear)]
def snapshot_blink_geomtree_effect_controller_init(evt : Event;
                                                   snapshot_blink_geomtree_effect_controller__fromEffectName : string;
                                                   snapshot_blink_geomtree_effect_controller__toEffectName : string;
                                                   var snapshot_blink_geomtree_effect_controller__fromEffectType : int&;
                                                   var snapshot_blink_geomtree_effect_controller__toEffectType : int&)
  if snapshot_blink_geomtree_effect_controller__fromEffectName != ""
    snapshot_blink_geomtree_effect_controller__fromEffectType = get_type_by_name(snapshot_blink_geomtree_effect_controller__fromEffectName)

  if snapshot_blink_geomtree_effect_controller__toEffectName != ""
    snapshot_blink_geomtree_effect_controller__toEffectType = get_type_by_name(snapshot_blink_geomtree_effect_controller__toEffectName)


def start_blink_geomtree_effect_for_node(from_fx_type : int;
                                         to_fx_type : int;
                                         animchar : AnimcharBaseComponent;
                                         node_idx : int;
                                         ctm : float3x4;
                                         ctm_volume : float;
                                         volume_per_effect : float;
                                         offs_delta : float3;
                                         transition_templates : StringList;
                                         from : float3;
                                         to : float3)

  var nodeTm : float3x4
  geomtree_getNodeWtmRelScalar(*animchar.nodeTree, node_idx, nodeTm)

  // WARNING: Dirty hack ahead!
  // At the moment, we don't have the ability to directly set the number of particles
  // depending on the volume of the emitter, so we will do it bluntly
  // by proportionally increasing the number of emitters themselves
  let effectsCount = clamp(roundi(ctm_volume / volume_per_effect), 1, 3)

  var fromTm = nodeTm
  fromTm[3] += from + offs_delta
  fromTm = fromTm * ctm
  if from_fx_type >= 0
    for _ in range(effectsCount)
      start_effect(from_fx_type, fromTm, IDENT_TM, false)


  var toTm = nodeTm
  toTm[3] += to + offs_delta
  toTm = toTm * ctm
  if to_fx_type >= 0
    for _ in range(effectsCount)
      start_effect(to_fx_type, toTm, IDENT_TM, false)

  for transitionTemplate in transition_templates
    createEntity(string(transitionTemplate)) <| $ [es] (var init : ComponentsInitializer)
      init |> set("transform", fromTm)
      init |> set("snapshot_blink_geomtree_transition_effect__fromPos", fromTm[3])
      init |> set("snapshot_blink_geomtree_transition_effect__toPos", toTm[3])


[es(tag=gameClient, REQUIRE_NOT=game_effect_geomtree_nodes_cache__ctm)]
def blink_geomtree_effect(evt : EventSnapshotBlink;
                          @shared_comp capsule_approximation : CapsuleApproximation;
                          animchar : AnimcharBaseComponent;
                          transform aka geomtree_transform : float3x4;
                          snapshot_blink_geomtree_effect_controller__distanceToCameraSq : float;
                          snapshot_blink_geomtree_effect_controller__fromEffectType : int;
                          snapshot_blink_geomtree_effect_controller__toEffectType : int;
                          snapshot_blink_geomtree_effect_controller__volumePerEffect : float;
                          snapshot_blink_geomtree_effect_controller__transitionTemplates : StringList)
  find_query() <| $ [es] (camera__active : bool; transform aka camera_transform : float3x4)
    if !camera__active
      return false

    let distanceToCamSq = distance_sq(camera_transform[3], geomtree_transform[3])
    if distanceToCamSq > snapshot_blink_geomtree_effect_controller__distanceToCameraSq
      return true

    assume fromEffectType = snapshot_blink_geomtree_effect_controller__fromEffectType
    assume toEffectType = snapshot_blink_geomtree_effect_controller__toEffectType
    assume volumePerEffect = snapshot_blink_geomtree_effect_controller__volumePerEffect
    assume transitionTemplates = snapshot_blink_geomtree_effect_controller__transitionTemplates

    var animcharRootTm = IDENT_TM
    animchar |> animchar_get_tm(animcharRootTm)
    let offsDelta = geomtree_getWtmOfs(*animchar.nodeTree) - animcharRootTm[3]

    for data in capsule_approximation.capsuleDatas
      let nodeIdx = data.nodeIndex
      let ctm <- make_tm_for_capsule_node(data)
      let ctmVolume = length(ctm[0]) * length(ctm[1]) * length(ctm[2])

      start_blink_geomtree_effect_for_node(fromEffectType, toEffectType, animchar,
                                           nodeIdx, ctm, ctmVolume, volumePerEffect, offsDelta,
                                           transitionTemplates, evt.from[3], evt.to[3])

    return true


[soa_es, es(tag=gameClient)]
def blink_geomtree_effect_cache(evt : EventSnapshotBlink;
                                nodes_cache : GameEffectGeomtreeNodesCache_SOA;
                                animchar : AnimcharBaseComponent;
                                transform aka geomtree_transform : float3x4;
                                snapshot_blink_geomtree_effect_controller__distanceToCameraSq : float;
                                snapshot_blink_geomtree_effect_controller__fromEffectType : int;
                                snapshot_blink_geomtree_effect_controller__toEffectType : int;
                                snapshot_blink_geomtree_effect_controller__volumePerEffect : float;
                                snapshot_blink_geomtree_effect_controller__transitionTemplates : StringList)
  find_query() <| $ [es] (camera__active : bool; transform aka camera_transform : float3x4)
    if !camera__active
      return false

    let distanceToCamSq = distance_sq(camera_transform[3], geomtree_transform[3])
    if distanceToCamSq > snapshot_blink_geomtree_effect_controller__distanceToCameraSq
      return true

    assume fromEffectType = snapshot_blink_geomtree_effect_controller__fromEffectType
    assume toEffectType = snapshot_blink_geomtree_effect_controller__toEffectType
    assume volumePerEffect = snapshot_blink_geomtree_effect_controller__volumePerEffect
    assume transitionTemplates = snapshot_blink_geomtree_effect_controller__transitionTemplates

    var animcharRootTm = IDENT_TM
    animchar |> animchar_get_tm(animcharRootTm)
    let offsDelta = geomtree_getWtmOfs(*animchar.nodeTree) - animcharRootTm[3]

    for nodeCache in nodes_cache
      let nodeIdx = nodeCache.game_effect_geomtree_nodes_cache__nodeIdx
      let ctm = nodeCache.game_effect_geomtree_nodes_cache__ctm
      let ctmVolume = nodeCache.game_effect_geomtree_nodes_cache__ctmVolume

      start_blink_geomtree_effect_for_node(fromEffectType, toEffectType, animchar,
                                           nodeIdx, ctm, ctmVolume, volumePerEffect, offsDelta,
                                           transitionTemplates, evt.from[3], evt.to[3])

    return true


[es(tag=gameClient, no_order)]
def snapshot_blink_geomtree_transition_effect_update(act : ParallelUpdateFrameDelayed;
                                                     eid : EntityId;
                                                     snapshot_blink_geomtree_transition_effect__fromPos : float3;
                                                     snapshot_blink_geomtree_transition_effect__toPos : float3;
                                                     snapshot_blink_geomtree_transition_effect__time : float;
                                                     snapshot_blink_geomtree_transition_effect__lerpPow : float;
                                                     var transform : float3x4;
                                                     var snapshot_blink_geomtree_transition_effect__timer : float&)
  assume timer = snapshot_blink_geomtree_transition_effect__timer
  assume time = snapshot_blink_geomtree_transition_effect__time
  assume lerpPow = snapshot_blink_geomtree_transition_effect__lerpPow
  assume fromPos = snapshot_blink_geomtree_transition_effect__fromPos
  assume toPos = snapshot_blink_geomtree_transition_effect__toPos

  timer += act.dt
  let progress = saturate(timer / time)
  let lerpKoef = pow(progress, lerpPow)

  let pos = lerp(fromPos, toPos, float3(lerpKoef))
  transform[3] = pos

  if timer >= time
    destroyEntity(eid)



[es(tag=gameClient, REQUIRE_NOT=game_effect_geomtree_nodes_cache__ctm)]
def blink_geomtree_effect_humanphys(evt : EventOnPlayerDash;
                                    @shared_comp capsule_approximation : CapsuleApproximation;
                                    animchar : AnimcharBaseComponent;
                                    transform aka geomtree_transform : float3x4;
                                    snapshot_blink_geomtree_effect_controller__distanceToCameraSq : float;
                                    snapshot_blink_geomtree_effect_controller__fromEffectType : int;
                                    snapshot_blink_geomtree_effect_controller__toEffectType : int;
                                    snapshot_blink_geomtree_effect_controller__volumePerEffect : float;
                                    snapshot_blink_geomtree_effect_controller__transitionTemplates : StringList)
  find_query() <| $ [es] (camera__active : bool; transform aka camera_transform : float3x4)
    if !camera__active
      return false

    let distanceToCamSq = distance_sq(camera_transform[3], geomtree_transform[3])
    if distanceToCamSq > snapshot_blink_geomtree_effect_controller__distanceToCameraSq
      return true

    assume fromEffectType = snapshot_blink_geomtree_effect_controller__fromEffectType
    assume toEffectType = snapshot_blink_geomtree_effect_controller__toEffectType
    assume volumePerEffect = snapshot_blink_geomtree_effect_controller__volumePerEffect
    assume transitionTemplates = snapshot_blink_geomtree_effect_controller__transitionTemplates

    var animcharRootTm = IDENT_TM
    animchar |> animchar_get_tm(animcharRootTm)
    let offsDelta = geomtree_getWtmOfs(*animchar.nodeTree) - animcharRootTm[3]

    for data in capsule_approximation.capsuleDatas
      let nodeIdx = data.nodeIndex
      let ctm <- make_tm_for_capsule_node(data)
      let ctmVolume = length(ctm[0]) * length(ctm[1]) * length(ctm[2])

      start_blink_geomtree_effect_for_node(fromEffectType, toEffectType, animchar,
                                           nodeIdx, ctm, ctmVolume, volumePerEffect, offsDelta,
                                           transitionTemplates, evt.from, evt.to)

    return true


[soa_es, es(tag=gameClient)]
def blink_geomtree_effect_humanphys_cache(evt : EventOnPlayerDash;
                                          nodes_cache : GameEffectGeomtreeNodesCache_SOA;
                                          animchar : AnimcharBaseComponent;
                                          transform aka geomtree_transform : float3x4;
                                          snapshot_blink_geomtree_effect_controller__distanceToCameraSq : float;
                                          snapshot_blink_geomtree_effect_controller__fromEffectType : int;
                                          snapshot_blink_geomtree_effect_controller__toEffectType : int;
                                          snapshot_blink_geomtree_effect_controller__volumePerEffect : float;
                                          snapshot_blink_geomtree_effect_controller__transitionTemplates : StringList)
  find_query() <| $ [es] (camera__active : bool; transform aka camera_transform : float3x4)
    if !camera__active
      return false

    let distanceToCamSq = distance_sq(camera_transform[3], geomtree_transform[3])
    if distanceToCamSq > snapshot_blink_geomtree_effect_controller__distanceToCameraSq
      return true

    assume fromEffectType = snapshot_blink_geomtree_effect_controller__fromEffectType
    assume toEffectType = snapshot_blink_geomtree_effect_controller__toEffectType
    assume volumePerEffect = snapshot_blink_geomtree_effect_controller__volumePerEffect
    assume transitionTemplates = snapshot_blink_geomtree_effect_controller__transitionTemplates

    var animcharRootTm = IDENT_TM
    animchar |> animchar_get_tm(animcharRootTm)
    let offsDelta = geomtree_getWtmOfs(*animchar.nodeTree) - animcharRootTm[3]

    for nodeCache in nodes_cache
      let nodeIdx = nodeCache.game_effect_geomtree_nodes_cache__nodeIdx
      let ctm = nodeCache.game_effect_geomtree_nodes_cache__ctm
      let ctmVolume = nodeCache.game_effect_geomtree_nodes_cache__ctmVolume

      start_blink_geomtree_effect_for_node(fromEffectType, toEffectType, animchar,
                                           nodeIdx, ctm, ctmVolume, volumePerEffect, offsDelta,
                                           transitionTemplates, evt.from, evt.to)

    return true