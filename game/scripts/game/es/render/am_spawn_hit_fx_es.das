require ecs
require ecs.safe
require game.events.events_active_matter
require danetlibs.renderer.includes.pufd_events
require math.base
require level
require Ballistics
require BallisticsProps
require DagorSystem
require DngWeapon
require DagorMath
require AnimV20
require CollRes


def find_flesh_effect_index(am_global_hit_fx__fleshEffects : Array;
                            key : string)
  for fleshEffectData, fleshEffectIndex in am_global_hit_fx__fleshEffects, iter_range(am_global_hit_fx__fleshEffects)
    if (fleshEffectData as Object)?.key ?? "" == key
      return fleshEffectIndex
  return -1


[es(tag=render, on_appear)]
def am_global_hit_fx_init(evt : Event;
                          am_global_hit_fx__fleshEffects : Array;
                          var am_global_hit_fx__projectileFleshEffectPresets : Array)
  for projectileFleshEffectPreset in am_global_hit_fx__projectileFleshEffectPresets
    var effectsPerEnergy = (projectileFleshEffectPreset as Object)?.effectsPerEnergy ?as Array
    if effectsPerEnergy != null
      for effectPerEnergyData in *effectsPerEnergy
        var effectPerEnergyObject = effectPerEnergyData as Object
        if effectPerEnergyObject != null
          let effectKey = *effectPerEnergyObject.effectKey ?? ""
          if effectKey != ""
            let effectIndex = find_flesh_effect_index(am_global_hit_fx__fleshEffects, effectKey)
            (*effectPerEnergyObject) |> set("effectIndex", effectIndex)


[es(tag=render, on_appear, on_event=EventLevelLoaded)]
def gun_hit_fx_blood_preset_init(evt : Event;
                                 gun_hit_fx__fleshPresetKey : string;
                                 var gun_hit_fx__fleshPresetIndex : int&)
  if !is_level_loaded()
    return

  if gun_hit_fx__fleshPresetKey != ""
    gun_hit_fx__fleshPresetIndex = -1
    find_query() <| $ [es] (am_global_hit_fx__projectileFleshEffectPresets : Array)
      assume presets = am_global_hit_fx__projectileFleshEffectPresets
      for presetData, presetIndex in presets, iter_range(presets)
        if (presetData as Object)?.key ?? "" == gun_hit_fx__fleshPresetKey
          gun_hit_fx__fleshPresetIndex = presetIndex
          break
      if gun_hit_fx__fleshPresetIndex == -1
        logerr("[GUN FX] Projectile flesh effect preset is not found: {gun_hit_fx__fleshPresetKey}")

      return true


def is_blood_enabled()
  var isEnabled = true
  find_query <| $ [es] (isBloodEnabled : bool)
    isEnabled = isBloodEnabled
    return true
  return isEnabled


def get_blood_color()
  var bloodColor = E3DCOLOR(0xFFFFFFFF)
  query() <| $ [es] (isBloodEnabled : bool; disabledBloodColor : E3DCOLOR)
    if !isBloodEnabled
      bloodColor = disabledBloodColor
  return bloodColor


def gen_fx_tm(pos : float3; dir : float3; scale : float)
  var tm = IDENT_TM
  tm[1] = normalize(dir)
  tm[2] = normalize(cross(float3(1, 0, 0), dir))
  tm[0] = normalize(cross(dir, tm[2]))
  for i in range(3)
    tm[i] = tm[i] * scale

  tm[3] = pos
  return tm


def spawn_human_binded_fx(fx_tm : float3x4; itm : float3x4; effect_template : string; eid : EntityId; node_coll_id : int; color_mult : E3DCOLOR)
  createEntity(effect_template) <| $(var init)
    init |> set("transform", fx_tm)
    init |> set("effect__colorMult", color_mult)
    init |> set("entity_binded_effect__entity", eid)
    init |> set("entity_binded_effect__collNodeId", node_coll_id)
    init |> set("entity_binded_effect__localEmitter", itm * fx_tm)


def am_human_spawn_blood_fx(victim_eid : EntityId;
                            coll_node_id : int;
                            blood_splash : HitBloodType;
                            pos : float3;
                            dir : float3;
                            scale : float;
                            norm : float3;
                            projectile_hit_fx__fleshPresetIndex : int;
                            projectile_ballistics : ProjectileBallistics;
                            projectile_ballistics_props : ProjectileProps)
  if !is_blood_enabled()
    return

  query(victim_eid) <| $ [es] (transform : float3x4;
                               animchar : AnimcharBaseComponent;
                               collres : CollisionResource)
    find_query() <| $ [es] (am_global_hit_fx__fleshEffects : Array;
                            am_global_hit_fx__projectileFleshEffectPresets : Array)

      var hitEntryFx = ""
      var hitSideFx = ""
      var hitExitFx = ""

      if projectile_hit_fx__fleshPresetIndex < 0 || projectile_hit_fx__fleshPresetIndex >= length(am_global_hit_fx__projectileFleshEffectPresets)
        logerr("[GUN FX] Invalid flesh effect preset index: {projectile_hit_fx__fleshPresetIndex}")
        return true

      let fleshEffectPreset = am_global_hit_fx__projectileFleshEffectPresets[projectile_hit_fx__fleshPresetIndex] as Object
      let effectsPerEnergy = fleshEffectPreset?.effectsPerEnergy ?as Array
      if effectsPerEnergy != null
        let speedSq = length_sq(projectile_ballistics.state.vel)
        let energy = projectile_ballistics_props.mass * speedSq * 0.5

        for effectPerEnergy in *effectsPerEnergy
          let upToEnergy = (effectPerEnergy as Object)?.upToEnergy ?? 0.0
          if upToEnergy == 0.0 || energy <= upToEnergy
            let effectIndex = (effectPerEnergy as Object)?.effectIndex ?? -1
            if effectIndex >= 0

              if effectIndex < 0 || effectIndex >= length(am_global_hit_fx__fleshEffects)
                logerr("[GUN FX] Invalid flesh effect preset index: {effectIndex}")
                return true

              let fleshEffect = am_global_hit_fx__fleshEffects[effectIndex] as Object
              hitEntryFx = fleshEffect?.hitEntryFx ?? ""
              hitSideFx = fleshEffect?.hitSideFx ?? ""
              hitExitFx = fleshEffect?.hitExitFx ?? ""
            break

      let bloodColor = get_blood_color()
      var nodeTm : float3x4
      collres_get_collision_node_tm(collres, coll_node_id, transform, animchar.nodeTree, nodeTm)
      let itm = inverse(nodeTm)
      spawn_human_binded_fx(gen_fx_tm(pos, -dir, scale), itm, hitEntryFx, victim_eid, coll_node_id, bloodColor)
      let reflectedDir = dir - 2. * dot(norm, dir) * norm
      if hitSideFx != "" && length_sq(reflectedDir) > 1e-5f
        spawn_human_binded_fx(gen_fx_tm(pos, ((normalize(reflectedDir) + norm) * 0.5f), scale), itm, hitSideFx, victim_eid, coll_node_id, bloodColor)

      if blood_splash != HitBloodType.TWO_SIDE || hitExitFx == "" || length_sq(dir) < FLT_EPSILON
        return true
      let t = 2.
      let tracePos = pos + 2. * dir
      let invDir = -dir
      collres_traceray(collres, transform, animchar.nodeTree, tracePos, invDir, t, true, uint8(BehaviorFlag.TRACEABLE)) <| $(find : bool; isects : CollResIntersectionsType#)
        if find
          let exitNodeId = int(isects[length(isects) - 1].collisionNodeId)
          spawn_human_binded_fx(gen_fx_tm(pos + (2.0f - t) * dir, dir, scale), itm, hitExitFx, victim_eid, exitNodeId, bloodColor)

      return true


[es(tag=render)]
def active_matter_on_shell_hit_entity_fx_es(evt : OnShellHitEntityFx)
  if evt.bloodSplash != HitBloodType.NONE
    query(evt.projectileEid) <| $ [es] (projectile_hit_fx__fleshPresetIndex : int;
                                        projectile_ballistics : ProjectileBallistics;
                                        projectile_ballistics_props : ProjectileProps)
      if projectile_hit_fx__fleshPresetIndex >= 0
        am_human_spawn_blood_fx(evt.victimEid, evt.nodeCollId, evt.bloodSplash,
                                evt.pos, evt.dir, 1.0, evt.norm,
                                projectile_hit_fx__fleshPresetIndex,
                                projectile_ballistics, projectile_ballistics_props)
