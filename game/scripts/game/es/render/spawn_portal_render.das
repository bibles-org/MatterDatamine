require ecs
require ecs.safe
require math.base


[es(tag=render, on_appear, REQUIRE=hero_spawn_portal)]
def hero_spawn_portal_effects_create(evt : Event;
                                     hero_spawn_portal__openEffects : Object;
                                     transform : float3x4;
                                     var hero_spawn_portal__effects : EidList)
  for it in hero_spawn_portal__openEffects
    let effectEid = createEntity(it.key) <| $(init)
      var scale = 1.0
      var offset : float3
      let valueAsP4 = it.value |> get_Point4()
      if valueAsP4 == null
        offset = it.value ?? float3()
      else
        offset = float3((*valueAsP4).x, (*valueAsP4).y, (*valueAsP4).z)
        scale = (*valueAsP4).w
      var tm = scale_tm(scale)
      tm[3] = transform * offset
      init |> set("transform", tm)
    hero_spawn_portal__effects |> push(effectEid)


[es(tag=render, after=portal_scaling_reverse, REQUIRE=hero_spawn_portal)]
def hero_spawn_portal_effects_scale(act : UpdateStageInfoAct;
                                    hero_spawn_portal__effects : EidList;
                                    portal__curScale, portal__radiusOffset : float)
  for effect in hero_spawn_portal__effects
    query(effect) <| $ [es(REQUIRE_NOT=lightEffect)] (var transform : float3x4&)
      var newTm = scale_tm(portal__curScale + portal__radiusOffset)
      newTm[3] = transform[3]
      transform = newTm


[es(tag=render, on_disappear, REQUIRE=hero_spawn_portal)]
def hero_spawn_portal_effects_remove(evt : Event;
                                     var hero_spawn_portal__effects : EidList)
  for effect in hero_spawn_portal__effects
    destroyEntity(effect)
  hero_spawn_portal__effects |> clear()
