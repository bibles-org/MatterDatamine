module ricocheted_fx_common

require ecs
require ecs.safe
require DagorRandom
require danetlibs.weaponry_hit_fx.render.falling_piece_common
require danetlibs.weaponry_hit_fx.main.weaponry_fx_common
require fx
require DaWeaponProps
require DagorMath


let DEFAULT_CHANCE = -1.0
let DEFAULT_VELOCITY = 5.0
let DEFAULT_ANGULAR_SPEED = 5.0


def private get_fx_float(fx_info : Object; fx_list_element : string; def_fx_element : string; mat_id : int; default_value : float)
  var fxValue = fx_info[def_fx_element] ?? default_value

  let fxs = get_ecs_FloatList(fx_info[fx_list_element])
  if fxs != null
    let elem = float((*fxs)[mat_id])
    if elem > 0.0
      fxValue = elem

  return fxValue


def private get_name(effect_group : Object;
                     mat_id : int;
                     impact_result : EffectImpactResult)
  if impact_result == EffectImpactResult.Ricochet
    return get_fx_name(effect_group, "ricochetedFxs", "defaultRicochetedFxType", mat_id)
  elif impact_result == EffectImpactResult.Stop
    return get_fx_name(effect_group, "destroyedFxs", "defaultDestroyedFxType", mat_id)

  return ""


def private get_probability(effect_group : Object;
                            mat_id : int;
                            impact_result : EffectImpactResult)
  if impact_result == EffectImpactResult.Ricochet
    return get_fx_float(effect_group, "ricochetedFxChance", "defaultRicochetedFxChance", mat_id, DEFAULT_CHANCE)
  elif impact_result == EffectImpactResult.Stop
    return get_fx_float(effect_group, "destroyedFxChance", "defaultDestroyedFxChance", mat_id, DEFAULT_CHANCE)

  return DEFAULT_CHANCE


def private get_velocity(effect_group : Object;
                         mat_id : int;
                         impact_result : EffectImpactResult)
  if impact_result == EffectImpactResult.Ricochet
    return get_fx_float(effect_group, "ricochetedFxVelocity", "defaultRicochetedFxVelocity", mat_id, DEFAULT_VELOCITY)
  elif impact_result == EffectImpactResult.Stop
    return get_fx_float(effect_group, "destroyedFxVelocity", "defaultDestroyedFxVelocity", mat_id, DEFAULT_VELOCITY)

  return DEFAULT_VELOCITY


def private get_angular_speed(effect_group : Object;
                              mat_id : int;
                              impact_result : EffectImpactResult)
  if impact_result == EffectImpactResult.Ricochet
    return get_fx_float(effect_group, "ricochetedFxAngularSpeed", "defaultRicochetedFxAngularSpeed", mat_id, DEFAULT_ANGULAR_SPEED)
  elif impact_result == EffectImpactResult.Stop
    return get_fx_float(effect_group, "destroyedFxAngularSpeed", "defaultDestroyedFxAngularSpeed", mat_id, DEFAULT_ANGULAR_SPEED)

  return DEFAULT_ANGULAR_SPEED


def current_head_color(projectile_tracer_props : ProjectileTracerProps; projectile__lifeTime : float)
  let startTime = projectile_tracer_props.startTime
  let startFade = saturate(safediv(projectile__lifeTime, startTime))

  let headColor = float3(projectile_tracer_props.headColor)
  let startHeadColor = float3(projectile_tracer_props.startHeadColor)
  let currentHeadColor = lerp(startHeadColor, headColor, startFade)
  return E3DCOLOR(Color4(float4(currentHeadColor, 1.0)))


def spawn_ricocheted_fx(pos, norm : float3;
                        effectGroup : Object;
                        mat_id : int;
                        impact_result : EffectImpactResult;
                        projectile__lifeTime : float;
                        projectile_tracer_props : ProjectileTracerProps const?)

  if mat_id < 0 || int(get_fx_target()) <= int(FxQuality.FX_QUALITY_MEDIUM)
    return

  let fxName = get_name(effectGroup, mat_id, impact_result)
  if empty(fxName)
    return

  let fxChance = get_probability(effectGroup, mat_id, impact_result)
  if fxChance <= 0.0 || gfrnd() > fxChance
    return

  let fxVelocity = get_velocity(effectGroup, mat_id, impact_result)
  let angularSpeed = get_angular_speed(effectGroup, mat_id, impact_result)
  spawn_falling_piece(fxName, fxVelocity, angularSpeed, pos, norm) <| $(init)
    if projectile_tracer_props != null
      init |> set("effect__colorMult", current_head_color(deref(projectile_tracer_props), projectile__lifeTime))
