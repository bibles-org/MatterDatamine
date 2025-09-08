require ecs
require math.base
require game.events.vehicle_events
require game.events.events_active_matter
require DagorSystem
require DagorMath
require Grid


[es(tag=gameClient, no_order)]
def update_optimised_visual_effects(act : ParallelUpdateFrameDelayed;
                                    visual_effects_optimiser__interval : float;
                                    visual_effects_optimiser__grids : StringList;
                                    visual_effects_optimiser__radius : float;
                                    var visual_effects_optimiser__enabledEids : EidList;
                                    var visual_effects_optimiser__gridIdx : int&;
                                    var visual_effects_optimiser__updateAt : float&)
  if act.curTime > visual_effects_optimiser__updateAt
    visual_effects_optimiser__updateAt = act.curTime + visual_effects_optimiser__interval
    visual_effects_optimiser__gridIdx = (visual_effects_optimiser__gridIdx + 1) % length(visual_effects_optimiser__grids)
    var keyPos : float3
    find_query() <| $ [es] (camera__active : bool; transform : float3x4)
      if camera__active
        keyPos = transform[3]
        return true
      return false

    var enabled, disabled : int

    let radiusSq = square(visual_effects_optimiser__radius)
    if visual_effects_optimiser__gridIdx == 0
      var i = length(visual_effects_optimiser__enabledEids)
      while i-- > 0
        query(visual_effects_optimiser__enabledEids[i]) <| $ [es] (transform : float3x4;
                                                                   var optimised_effect_source__effectEid : EntityId&)
          let shouldExist = distance_sq(keyPos, transform[3]) < radiusSq
          if !shouldExist
            disabled++
            destroyEntity(optimised_effect_source__effectEid)
            optimised_effect_source__effectEid = INVALID_ENTITY_ID
            visual_effects_optimiser__enabledEids |> erase(i)

    let gridHash = ecs_hash(string(visual_effects_optimiser__grids[visual_effects_optimiser__gridIdx]))
    for_each_entity_in_grid(gridHash, BSphere3(keyPos, visual_effects_optimiser__radius), GridEntCheck.POS) <| $(eid : EntityId)
      query(eid) <| $ [es(REQUIRE_NOT=disable_optimised_visual_effect)] (optimised_effect_source__template : string;
                                                                         transform : float3x4;
                                                                         var optimised_effect_source__effectEid : EntityId&)
        if optimised_effect_source__effectEid == INVALID_ENTITY_ID
          enabled++
          optimised_effect_source__effectEid = createEntity(optimised_effect_source__template) <| $(init)
            init |> set("transform", transform)
          visual_effects_optimiser__enabledEids |> push(eid)
    //if enabled != 0 || disabled != 0
    //  print("VISUAL EFFECTS OPTIMISER: +: {enabled} -: {disabled} active: {length(visual_effects_optimiser__enabledEids)}")

[es(tag=gameClient, on_disappear)]
def destroy_fx_on_parent_disappear(evt : Event; optimised_effect_source__effectEid : EntityId)
  destroyEntity(optimised_effect_source__effectEid)