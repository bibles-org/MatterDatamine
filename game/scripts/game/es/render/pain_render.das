require ecs
require danetlibs.renderer.includes.render_events


def private destroy_pain_render_effect_impl(owner_eid : EntityId)
  find_query() <| $ [es(REQUIRE=painRenderEffect)] (eid, game_effect__attachedTo : EntityId)
    if game_effect__attachedTo == owner_eid
      destroyEntity(eid)
      return true
    return false


[es(tag=render, on_appear, track=pain__active, REQUIRE=watchedByPlr)]
def make_or_destroy_pain_render_effect(evt : Event;
                                       eid aka owner_eid : EntityId;
                                       pain__active : bool;
                                       pain__renderEffectsTemplateName : string)
  if pain__active
    createEntity(pain__renderEffectsTemplateName) <| $(var init)
      set(init, "game_effect__attachedTo", owner_eid)
  else
    destroy_pain_render_effect_impl(owner_eid)


[es(tag=render, on_disappear, REQUIRE=watchedByPlr)]
def destroy_pain_render_effect(evt : Event;
                               eid aka owner_eid : EntityId;
                               pain__active : bool)
  if pain__active
    destroy_pain_render_effect_impl(owner_eid)


[es(tag=render, after=pain_intensity, before=screen_effect_render_es, REQUIRE=watchedByPlr)]
def pain_screen_effect(info : UpdateStageInfoBeforeRender;
                       pain__intensity : float)
  query() <| $ [es(REQUIRE=painScreenEffect)] (pain_screen_effect__intensityMult : float;
                                               pain_screen_effect__intensityMinMax : float2;
                                               var screen_effect__intensity : float&)
    screen_effect__intensity = clamp(pain__intensity * pain_screen_effect__intensityMult,
      pain_screen_effect__intensityMinMax.x, pain_screen_effect__intensityMinMax.y)


[es(tag=render, after=pain_intensity, before=force_concussion_screen_effect)]
def pain_force_concussion_screen_effect(info : UpdateStageInfoAct;
                                        game_effect__attachedTo : EntityId;
                                        force_concussion_screen_effect__intensityMult : float;
                                        var force_concussion_screen_effect__intensity : float&)
  query(game_effect__attachedTo) <| $ [es(REQUIRE=watchedByPlr)] (pain__intensity : float)
    force_concussion_screen_effect__intensity = pain__intensity * force_concussion_screen_effect__intensityMult