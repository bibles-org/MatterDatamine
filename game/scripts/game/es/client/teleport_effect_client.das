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
def teleport_effect_controller_init(evt : Event;
                                    teleport_effect_controller__fromEffectName : string;
                                    teleport_effect_controller__toEffectName : string;
                                    var teleport_effect_controller__fromEffectType : int&;
                                    var teleport_effect_controller__toEffectType : int&)
  if teleport_effect_controller__fromEffectName != ""
    teleport_effect_controller__fromEffectType = get_type_by_name(teleport_effect_controller__fromEffectName)

  if teleport_effect_controller__toEffectName != ""
    teleport_effect_controller__toEffectType = get_type_by_name(teleport_effect_controller__toEffectName)


def start_teleport_geomtree_effect_for_node(from_fx_type : int;
                                            to_fx_type : int;
                                            animchar : AnimcharBaseComponent;
                                            node_idx : int;
                                            ctm : float3x4;
                                            ctm_volume : float;
                                            volume_per_effect : float;
                                            offs_delta : float3;
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


[es(tag=gameClient, REQUIRE_NOT=game_effect_geomtree_nodes_cache__ctm)]
def teleport_effect_controller_on_teleport(evt : EventNPhysTeleported;
                                           @shared_comp capsule_approximation : CapsuleApproximation;
                                           animchar : AnimcharBaseComponent;
                                           teleport_effect_controller__fromEffectType : int;
                                           teleport_effect_controller__toEffectType : int;
                                           teleport_effect_controller__volumePerEffect : float)
  assume fromEffectType = teleport_effect_controller__fromEffectType
  assume toEffectType = teleport_effect_controller__toEffectType
  assume volumePerEffect = teleport_effect_controller__volumePerEffect

  var animcharRootTm = IDENT_TM
  animchar |> animchar_get_tm(animcharRootTm)
  let offsDelta = geomtree_getWtmOfs(*animchar.nodeTree) - animcharRootTm[3]

  for data in capsule_approximation.capsuleDatas
    let nodeIdx = data.nodeIndex
    let ctm <- make_tm_for_capsule_node(data)
    let ctmVolume = length(ctm[0]) * length(ctm[1]) * length(ctm[2])

    start_teleport_geomtree_effect_for_node(fromEffectType, toEffectType, animchar,
                                          nodeIdx, ctm, ctmVolume, volumePerEffect, offsDelta,
                                          evt.from[3], evt.to[3])


[soa_es, es(tag=gameClient)]
def teleport_effect_controller_on_teleport_cache(evt : EventNPhysTeleported;
                                                 nodes_cache : GameEffectGeomtreeNodesCache_SOA;
                                                 animchar : AnimcharBaseComponent;
                                                 teleport_effect_controller__fromEffectType : int;
                                                 teleport_effect_controller__toEffectType : int;
                                                 teleport_effect_controller__volumePerEffect : float)
  assume fromEffectType = teleport_effect_controller__fromEffectType
  assume toEffectType = teleport_effect_controller__toEffectType
  assume volumePerEffect = teleport_effect_controller__volumePerEffect

  var animcharRootTm = IDENT_TM
  animchar |> animchar_get_tm(animcharRootTm)
  let offsDelta = geomtree_getWtmOfs(*animchar.nodeTree) - animcharRootTm[3]

  for nodeCache in nodes_cache
    let nodeIdx = nodeCache.game_effect_geomtree_nodes_cache__nodeIdx
    let ctm = nodeCache.game_effect_geomtree_nodes_cache__ctm
    let ctmVolume = nodeCache.game_effect_geomtree_nodes_cache__ctmVolume

    start_teleport_geomtree_effect_for_node(fromEffectType, toEffectType, animchar,
                                            nodeIdx, ctm, ctmVolume, volumePerEffect, offsDelta,
                                            evt.from[3], evt.to[3])