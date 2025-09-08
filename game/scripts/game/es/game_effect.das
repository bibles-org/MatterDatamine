require app
require ecs
require PhysVars
require DagorMath
require game.events.events_active_matter
require game.es.animation_curve_common


[es(tag=gameClient, after=actions_es, before=anim_state_es)]
def game_effect_forced_parametric_var_update(act : ParallelUpdateFrameDelayed;
                                             game_effect__attachedTo : EntityId;
                                             game_effect__timeToDestroy, game_effect__destroyAt : float;
                                             game_effect__forcedParametricVarName : string;
                                             var game_effect__forcedParametricVarId : int&)
  query(game_effect__attachedTo) <| $ [es] (var phys_vars : PhysVars)
    if game_effect__forcedParametricVarId == -1
      game_effect__forcedParametricVarId = phys_vars |> registerVar(game_effect__forcedParametricVarName, 0.0)
    let progress = 1. - safediv(game_effect__destroyAt - act.curTime, game_effect__timeToDestroy)
    phys_vars |> setVar(game_effect__forcedParametricVarId, progress)


[es(tag=gameClient)]
def game_effect_scale_me_to_zero(act : ParallelUpdateFrameDelayed; game_effect__scaleMePerSecond : float; var transform : float3x4)
  if act.dt > 0.0
    let factor = pow(game_effect__scaleMePerSecond, act.dt)
    transform[0] *= factor
    transform[1] *= factor
    transform[2] *= factor


[es(on_appear)]
def game_effect_animate_float_component_init(evt : Event;
                                             animate_float_component__componentName : string;
                                             var animate_float_component__createdAt : float&;
                                             var animate_float_component__componentHash : uint&)
  animate_float_component__createdAt = get_sync_time()
  animate_float_component__componentHash = ecs_hash(animate_float_component__componentName)


[es(no_order)]
def game_effect_animate_float_component_update(upd : ParallelUpdateFrameDelayed;
                                               eid aka effect_eid : EntityId;
                                               game_effect__attachedTo : EntityId;
                                               animate_float_component__createdAt : float;
                                               animate_float_component__componentName : string;
                                               animate_float_component__componentHash : uint;
                                               animate_float_component__curve : Array)
  var componentRef = getRW_float(game_effect__attachedTo, animate_float_component__componentName, animate_float_component__componentHash)
  if componentRef == null
    error("[ANIMATE FLOAT COMPONENT] Component {animate_float_component__componentName} not found in entity <{game_effect__attachedTo}>")
    destroyEntity(effect_eid)
    return

  let timePassed = upd.curTime - animate_float_component__createdAt
  let value = animation_curve_evaluate_linear(animate_float_component__curve, timePassed)
  *componentRef = value
