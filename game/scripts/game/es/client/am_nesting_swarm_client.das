require app
require ecs
require ecs.common
require ecs.soa_template
require math.base
require math.random
require game.events.events_game
require game.es.game_effect_geomtree_common
require game.es.swarm_common
require fx
require DagorSystem
require DagorMath
require AnimV20
require GeomNodeTree
require CapsuleApproximation


[es(tag=gameClient, on_appear)]
def nesting_swarm_nest_death_effect_controller_init(evt : Event;
                                                    nesting_swarm_nest_death_effect_controller__effectName : string;
                                                    var nesting_swarm_nest_death_effect_controller__effectType : int&)
  if nesting_swarm_nest_death_effect_controller__effectName != ""
    nesting_swarm_nest_death_effect_controller__effectType = get_type_by_name(nesting_swarm_nest_death_effect_controller__effectName)


def start_geomtree_effect_for_node(fx_type : int;
                                   animchar : AnimcharBaseComponent;
                                   node_idx : int;
                                   ctm : float3x4;
                                   ctm_volume : float;
                                   volume_per_effect : float;
                                   offs_delta : float3;
                                   tm : float3x4)
  if fx_type < 0
    return

  var nodeTm : float3x4
  geomtree_getNodeWtmRelScalar(*animchar.nodeTree, node_idx, nodeTm)

  // WARNING: Dirty hack ahead!
  // At the moment, we don't have the ability to directly set the number of particles
  // depending on the volume of the emitter, so we will do it bluntly
  // by proportionally increasing the number of emitters themselves
  let effectsCount = clamp(roundi(ctm_volume / volume_per_effect), 1, 3)

  var fxTm = nodeTm
  fxTm[3] += tm[3] + offs_delta
  fxTm = fxTm * ctm
  for _ in range(effectsCount)
    start_effect(fx_type, fxTm, IDENT_TM, false)


[soa_es, es(tag=gameClient)]
def nesting_swarm_nest_death_effect_controller_trigger(evt : EventEntityDied;
                                                       nodes_cache : GameEffectGeomtreeNodesCache_SOA;
                                                       animchar : AnimcharBaseComponent;
                                                       transform aka geomtree_transform : float3x4;
                                                       nesting_swarm_nest_death_effect_controller__distanceToCameraSq : float;
                                                       nesting_swarm_nest_death_effect_controller__effectType : int;
                                                       nesting_swarm_nest_death_effect_controller__volumePerEffect : float;
                                                       nesting_swarm_nest_death_effect_controller__deathSwarmTemplate : string;
                                                       nesting_swarm_nest_death_effect_controller__deathSwarmOffset : float3)
  find_query() <| $ [es] (camera__active : bool; transform aka camera_transform : float3x4)
    if !camera__active
      return false

    let distanceToCamSq = distance_sq(camera_transform[3], geomtree_transform[3])
    if distanceToCamSq > nesting_swarm_nest_death_effect_controller__distanceToCameraSq
      return true

    assume effectType = nesting_swarm_nest_death_effect_controller__effectType
    assume volumePerEffect = nesting_swarm_nest_death_effect_controller__volumePerEffect

    var animcharRootTm = IDENT_TM
    animchar |> animchar_get_tm(animcharRootTm)
    let offsDelta = geomtree_getWtmOfs(*animchar.nodeTree) - animcharRootTm[3]

    for nodeCache in nodes_cache
      let nodeIdx = nodeCache.game_effect_geomtree_nodes_cache__nodeIdx
      let ctm = nodeCache.game_effect_geomtree_nodes_cache__ctm
      let ctmVolume = nodeCache.game_effect_geomtree_nodes_cache__ctmVolume

      start_geomtree_effect_for_node(effectType, animchar, nodeIdx, ctm, ctmVolume,
                                     volumePerEffect, offsDelta, geomtree_transform)

    if nesting_swarm_nest_death_effect_controller__deathSwarmTemplate != ""
      createEntity(nesting_swarm_nest_death_effect_controller__deathSwarmTemplate) <| $ [es] (var init : ComponentsInitializer)
        var tm = geomtree_transform
        tm[3] += rotate(geomtree_transform, nesting_swarm_nest_death_effect_controller__deathSwarmOffset)
        init |> set("transform", tm)

    return true


[es(tag=gameClient, on_appear)]
def nesting_swarm_nest_death_swarm_boid_element(evt : Event;
                                                nesting_swarm_nest_death_swarm_boid_element__impulse : float;
                                                boid__dyingTime : float = 5.5;
                                                var velocity : float3&;
                                                var staying_time : float&;
                                                var boid_state : int&;
                                                var boid__isHitted : bool&)
  boid_state = int(BoidState.BOID_DEAD)
  staying_time = boid__dyingTime
  boid__isHitted = true

  // Non-uniform impulse distribution
  let r = grnd() % 5
  if r == 0
    velocity = rnd_dir3() * rnd_float(0.88, 1.0) * nesting_swarm_nest_death_swarm_boid_element__impulse
  elif r >= 1 && r <= 2
    velocity = rnd_dir3() * rnd_float(0.05, 1.0) * nesting_swarm_nest_death_swarm_boid_element__impulse
  else
    velocity = rnd_dir3() * rnd_float(0.11, 0.25) * nesting_swarm_nest_death_swarm_boid_element__impulse
  velocity.y = abs(velocity.y)