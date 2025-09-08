require ecs
require ecs.common
require ecs.soa_template
require ecs.safe
require math
require math.base
require game.events.events
require CapsuleApproximation
require game.es.node_attach_common
require game.events.events_active_matter
require game.es.render.effect_animation_common
require game.es.game_effect_geomtree_common
require DagorSystem
require DagorMath
require GeomNodeTree
require AnimV20
require strings


enum GameEffectGeomtreeEffectsFlags
  IGNORE_CAPSULE_SCALE = 0x1


[soa_template]
struct GameEffectGeomtreeEffectsQueue
  game_effect_geomtree_effects_queue__ctm : float3x4
  game_effect_geomtree_effects_queue__templ : string
  game_effect_geomtree_effects_queue__nodeIdx : int
  game_effect_geomtree_effects_queue__flags : int


[soa_es, es(tag=gameClient, on_appear)]
def game_effect_geomtree_nodes_cache_init(evt : Event;
                                          @shared_comp capsule_approximation : CapsuleApproximation;
                                          game_effect__geomtreeEffectIgnoreNodeIndices : IntList const?;
                                          var nodes_cache : GameEffectGeomtreeNodesCache_SOA)
  for data in capsule_approximation.capsuleDatas

    if game_effect__geomtreeEffectIgnoreNodeIndices != null
      if *game_effect__geomtreeEffectIgnoreNodeIndices |> find_index(int(data.nodeIndex)) >= 0
        continue

    let ctm <- make_tm_for_capsule_node(data)
    let ctmVolume = length(ctm[0]) * length(ctm[1]) * length(ctm[2])

    nodes_cache |> push() <| GameEffectGeomtreeNodesCache(
      game_effect_geomtree_nodes_cache__ctm = ctm,
      game_effect_geomtree_nodes_cache__ctmVolume = ctmVolume,
      game_effect_geomtree_nodes_cache__nodeIdx = int(data.nodeIndex)
    )


def init_ignore_nodes(eid : EntityId;
                      game_effect__attachedTo : EntityId;
                      game_effect__geomtreeEffectIgnoreNodeNames : StringList const?;
                      var game_effect__geomtreeEffectIgnoreNodeIndices : IntList?)
  if game_effect__geomtreeEffectIgnoreNodeNames != null && game_effect__geomtreeEffectIgnoreNodeIndices != null
    *game_effect__geomtreeEffectIgnoreNodeIndices |> clear()
    query(game_effect__attachedTo) <| $ [es] (animchar : AnimcharBaseComponent)
      for ignoreNodeName in *game_effect__geomtreeEffectIgnoreNodeNames
        let nodeIdx = geomtree_findNodeIndex(*animchar.nodeTree, ignoreNodeName |> string())
        if nodeIdx < 0
          logerr("Undefined node to ignore: {ignoreNodeName} for effect ({eid})<{getEntityTemplateName(eid)}>")
          continue
        *game_effect__geomtreeEffectIgnoreNodeIndices |> push(nodeIdx)


[soa_def]
def init_effects_to_create(game_effect__attachedTo : EntityId;
                           game_effect__geomtreeEffectTemplates : StringList;
                           game_effect__geomtreeEffectIgnoreCapsuleScale : BoolList const?;
                           game_effect__geomtreeEffectIgnoreNodeIndices : IntList const?;
                           var game_effect_geomtree_effects_queue : GameEffectGeomtreeEffectsQueue_SOA)
  if game_effect__attachedTo |> has("game_effect_geomtree_nodes_cache")
    query(game_effect__attachedTo) <| $ [soa_blk, es] (nodes_cache : GameEffectGeomtreeNodesCache_SOA)
      for nodeCache in nodes_cache

        if game_effect__geomtreeEffectIgnoreNodeIndices != null
          if *game_effect__geomtreeEffectIgnoreNodeIndices |> find_index(nodeCache.game_effect_geomtree_nodes_cache__nodeIdx) >= 0
            continue

        for i, effectTemplate in iter_range(game_effect__geomtreeEffectTemplates), game_effect__geomtreeEffectTemplates
          var flags = 0

          if game_effect__geomtreeEffectIgnoreCapsuleScale != null && i < *game_effect__geomtreeEffectIgnoreCapsuleScale |> length()
            if (*game_effect__geomtreeEffectIgnoreCapsuleScale)[i]
              flags |= int(GameEffectGeomtreeEffectsFlags.IGNORE_CAPSULE_SCALE)

          game_effect_geomtree_effects_queue |> push() <| GameEffectGeomtreeEffectsQueue(
            game_effect_geomtree_effects_queue__ctm = nodeCache.game_effect_geomtree_nodes_cache__ctm,
            game_effect_geomtree_effects_queue__templ = effectTemplate |> string(),
            game_effect_geomtree_effects_queue__nodeIdx = nodeCache.game_effect_geomtree_nodes_cache__nodeIdx,
            game_effect_geomtree_effects_queue__flags = flags
          )
  else
    query(game_effect__attachedTo) <| $ [es] (@shared_comp capsule_approximation : CapsuleApproximation)
      for data in capsule_approximation.capsuleDatas

        if game_effect__geomtreeEffectIgnoreNodeIndices != null
          if *game_effect__geomtreeEffectIgnoreNodeIndices |> find_index(int(data.nodeIndex)) >= 0
            continue

        let ctm <- make_tm_for_capsule_node(data)

        for i, effectTemplate in iter_range(game_effect__geomtreeEffectTemplates), game_effect__geomtreeEffectTemplates
          var flags = 0

          if game_effect__geomtreeEffectIgnoreCapsuleScale != null && i < *game_effect__geomtreeEffectIgnoreCapsuleScale |> length()
            if (*game_effect__geomtreeEffectIgnoreCapsuleScale)[i]
              flags |= int(GameEffectGeomtreeEffectsFlags.IGNORE_CAPSULE_SCALE)

          game_effect_geomtree_effects_queue |> push() <| GameEffectGeomtreeEffectsQueue(
              game_effect_geomtree_effects_queue__ctm = ctm,
              game_effect_geomtree_effects_queue__templ = effectTemplate |> string(),
              game_effect_geomtree_effects_queue__nodeIdx = int(data.nodeIndex),
              game_effect_geomtree_effects_queue__flags = flags
            )


[soa_es, es(tag=gameClient, on_appear)]
def game_effect_geomtree_appear_es(evt : Event;
                                   eid : EntityId;
                                   game_effect__attachedTo : EntityId;
                                   game_effect__showHideDistanceSq : float2;
                                   game_effect__geomtreeEffectTemplates : StringList;
                                   game_effect__geomtreeEffectIgnoreCapsuleScale : BoolList const?;
                                   game_effect__geomtreeEffectIgnoreNodeNames : StringList const?;
                                   var game_effect__geomtreeEffectIgnoreNodeIndices : IntList?;
                                   var game_effect_geomtree_effects_queue : GameEffectGeomtreeEffectsQueue_SOA)
  if game_effect__showHideDistanceSq.x > game_effect__showHideDistanceSq.y
    logerr("[game_effect_geomtree_effects] show distance <game_effect__showHideDistanceSq.x> must be less then hide distance <game_effect__showHideDistanceSq.y>")
    return

  if isLoadingEntity(game_effect__attachedTo)
    addSubTemplate(eid, "game_effect_geomtree_effects_delayed_init")
  else
    init_ignore_nodes(eid,
                      game_effect__attachedTo,
                      game_effect__geomtreeEffectIgnoreNodeNames,
                      game_effect__geomtreeEffectIgnoreNodeIndices)
    init_effects_to_create(game_effect__attachedTo,
                          game_effect__geomtreeEffectTemplates,
                          game_effect__geomtreeEffectIgnoreCapsuleScale,
                          game_effect__geomtreeEffectIgnoreNodeIndices,
                          game_effect_geomtree_effects_queue)


[soa_es, es(tag=gameClient, no_order, REQUIRE=game_effect_geomtree_effects_delayed_init)]
def game_effect_geomtree_effects_delayed_init(act : UpdateStageInfoAct;
                                              eid : EntityId;
                                              game_effect__attachedTo : EntityId;
                                              game_effect__geomtreeEffectTemplates : StringList;
                                              game_effect__geomtreeEffectIgnoreCapsuleScale : BoolList const?;
                                              game_effect__geomtreeEffectIgnoreNodeNames : StringList const?;
                                              var game_effect__geomtreeEffectIgnoreNodeIndices : IntList?;
                                              var game_effect_geomtree_effects_queue : GameEffectGeomtreeEffectsQueue_SOA)
  if !isLoadingEntity(game_effect__attachedTo)
    init_ignore_nodes(eid,
                      game_effect__attachedTo,
                      game_effect__geomtreeEffectIgnoreNodeNames,
                      game_effect__geomtreeEffectIgnoreNodeIndices)
    init_effects_to_create(game_effect__attachedTo,
                           game_effect__geomtreeEffectTemplates,
                           game_effect__geomtreeEffectIgnoreCapsuleScale,
                           game_effect__geomtreeEffectIgnoreNodeIndices,
                           game_effect_geomtree_effects_queue)
    removeSubTemplate(eid, "game_effect_geomtree_effects_delayed_init")


[soa_es, es(tag=gameClient, no_order, REQUIRE_NOT=game_effect_geomtree_effects_delayed_init)]
def game_effect_geomtree_update_es(evt : ParallelUpdateFrameDelayed;
                                   game_effect__attachedTo : EntityId;
                                   game_effect__showHideDistanceSq : float2;
                                   game_effect__geomtreeEffectTemplates : StringList;
                                   game_effect__geomtreeEffectIgnoreCapsuleScale : BoolList const?;
                                   game_effect__geomtreeEffectIgnoreNodeIndices : IntList const?;
                                   var effects_queue : GameEffectGeomtreeEffectsQueue_SOA;
                                   var game_effect__geomtreeEffectEntities : EidList;
                                   game_effect_geomtree_effects__createLimitPerAct : int = 10)
  let totalEffectQueryCount = length(effects_queue)
  find_query() <| $ [es] (camera__active : bool; transform aka camera_transform : float3x4)
    if !camera__active
      return false
    query(game_effect__attachedTo) <| $ [es] (animchar : AnimcharBaseComponent; transform aka attached_to_transform : float3x4)
      let distanceToCamSq = distance_sq(camera_transform[3], attached_to_transform[3])
      if distanceToCamSq >= game_effect__showHideDistanceSq.y
        if length(game_effect__geomtreeEffectEntities) == 0 // already cleaned
          return
        // out of range, destroy old effects
        for effectEid in game_effect__geomtreeEffectEntities
          destroyEntity(effectEid)
        game_effect__geomtreeEffectEntities |> clear()
        // reinit effect query for next creation
        effects_queue |> clear()
        init_effects_to_create(game_effect__attachedTo,
                               game_effect__geomtreeEffectTemplates,
                               game_effect__geomtreeEffectIgnoreCapsuleScale,
                               game_effect__geomtreeEffectIgnoreNodeIndices,
                               effects_queue)
      elif totalEffectQueryCount > 0 && distanceToCamSq < game_effect__showHideDistanceSq.x
        // want to create effects
        let createCount = min(game_effect_geomtree_effects__createLimitPerAct, totalEffectQueryCount)
        for i in range(createCount)
          let templ = effects_queue[i].game_effect_geomtree_effects_queue__templ |> string()
          let effectTempl = getTemplateByName(templ)
          let scaleInvTmScale = getTemplateComponent(*effectTempl, "effect__scaleInvTmScale") ?? 0.0
          let ctm = effects_queue[i].game_effect_geomtree_effects_queue__ctm
          let nodeIdx = effects_queue[i].game_effect_geomtree_effects_queue__nodeIdx
          let flags = effects_queue[i].game_effect_geomtree_effects_queue__flags
          let ignoreCapsuleScale = (flags & int(GameEffectGeomtreeEffectsFlags.IGNORE_CAPSULE_SCALE)) != 0
          var tm : float3x4

          geomtree_getNodeWtmScalar(*animchar.nodeTree, int(nodeIdx), tm)
          tm = ignoreCapsuleScale ? tm : tm * ctm
          let effectEid = createEntity(templ) <| $(var init : ComponentsInitializer)
            set(init, "transform", tm)
            attach_to_node(init, game_effect__attachedTo, nodeIdx, ignoreCapsuleScale ? IDENT_TM : ctm)
            if scaleInvTmScale != 0.0
              // For burst fxs it's too late set effect__scale on appear
              // So we should set it right here
              set(init, "effect__scale", safediv(scaleInvTmScale, length(tm[0])))
          game_effect__geomtreeEffectEntities |> push(effectEid)
        effects_queue |> erase(0, createCount)
    return true


[es(tag=gameClient, on_disappear, REQUIRE=game_effect__geomtreeEffectTemplates)]
def game_effect_geomtree_disappear_es(evt : Event;
                                      var game_effect__geomtreeEffectEntities : EidList)
  for effectEid in game_effect__geomtreeEffectEntities
    destroyEntity(effectEid)
  game_effect__geomtreeEffectEntities |> clear()