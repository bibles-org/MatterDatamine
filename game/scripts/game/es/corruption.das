require ecs
require app
require math.base
require game.events.events
require game.events.events_active_matter
require game.es.entity_mods_common
require dm
require DngDm
require DagorMath


def calc_dmg(zone_dmg, corruption_value, doubling_time : float)
  return zone_dmg * pow(2.0, corruption_value / doubling_time)


def get_corruption_effect_eid()
  var res = INVALID_ENTITY_ID
  find_query() <| $ [es(REQUIRE=corruption_effect)] (eid : EntityId)
    res = eid
    return true
  return res


[es(tag=server, after=dmgzone_es)]
def corruption_zone_update(act : ParallelUpdateFrameDelayed;
                           eid aka offender_eid : EntityId;
                           dmgzone__eidsInZone : EidList;
                           dmgzone__updateInterval : float = 1.0;
                           dmgzone__lastUpdate : float;
                           corruption_zone__doublingTime : float;
                           corruption_zone__damage : float;
                           corruption_zone__playerFx : string = "";
                           dm__damageTypeId : int = int(DamageType.DM_ZONE))
  if dmgzone__lastUpdate != act.curTime
    return //Update on the same frame as dmgzone_es
  for eidInZone in dmgzone__eidsInZone
    query(eidInZone) <| $ [es] (transform : float3x4;
                                entity_mod_values : Object const?;
                                var human_corruption__lastTime : float&;
                                var human_corruption__value : float&)
      human_corruption__lastTime = act.curTime
      human_corruption__value += dmgzone__updateInterval
      let damageMult = entity_mod_values == null ? 1.0 : get_mod_value("corruptionZoneDamageMult", *entity_mod_values, 1.0)
      let damage = calc_dmg(corruption_zone__damage, human_corruption__value,  corruption_zone__doublingTime) * damageMult
      let ddesc = DamageDesc(DamageType(dm__damageTypeId), damage, transform[3])
      damage_entity(eidInZone, offender_eid, ddesc)
      if !empty(corruption_zone__playerFx)
        let hasFx = find_query() <| $ [es(REQUIRE=corrupted_player_effect)] (game_effect__attachedTo : EntityId;
                                                                             game_effect__timeToDestroy : float;
                                                                             var game_effect__destroyAt : float&)
          if game_effect__attachedTo == eidInZone
            game_effect__destroyAt = game_effect__timeToDestroy + act.curTime
            return true
          return false
        if !hasFx
          createEntity(corruption_zone__playerFx) <| $ [es] (init)
            init |> set("game_effect__attachedTo", eidInZone)
            init |> set("node_attached__entity", eidInZone)
            init |> set("transform", transform)


[es(tag=server, after=corruption_zone_update)]
def recover_from_corruption(act : ParallelUpdateFrameDelayed;
                            human_corruption__recoverMult : float;
                            human_corruption__updateInterval : float;
                            human_corruption__lastTime : float;
                            var human_corruption__isInCorruption : bool&;
                            var human_corruption__nextUpdateAt : float&;
                            var human_corruption__value : float&)
  if human_corruption__nextUpdateAt < act.curTime
    human_corruption__nextUpdateAt = act.curTime + human_corruption__updateInterval
    human_corruption__isInCorruption = act.curTime - human_corruption__lastTime <= human_corruption__updateInterval
    if !human_corruption__isInCorruption
      human_corruption__value = max(0.0, human_corruption__value - human_corruption__recoverMult * human_corruption__updateInterval)


[es(tag=gameClient, track=human_corruption__value, REQUIRE=watchedByPlr)]
def update_corruption_intensity(evt : Event;
                                human_corruption__value : float;
                                human_corruption__criticalDamage : float;
                                human_corruption__relativeIntensityRng : float2;
                                var human_corruption__relativeIntensity : float&)
  find_query() <| $ [es] (corruption_zone__doublingTime, corruption_zone__damage : float)
    //Corruption value at which damage is going to be qual to human_corruption__criticalDamage:
    let intensityFullAt = log(safediv(human_corruption__criticalDamage, corruption_zone__damage)) / log(2.0) * corruption_zone__doublingTime
    human_corruption__relativeIntensity = safediv(human_corruption__value, intensityFullAt)
    assume intensityRng = human_corruption__relativeIntensityRng
    human_corruption__relativeIntensity = cvt(human_corruption__relativeIntensity, 0.0, 1.0, intensityRng.x, intensityRng.y)
    return true


[es(tag=render, on_appear, track=human_corruption__isInCorruption, REQUIRE=watchedByPlr)]
def create_or_destroy_corruption_effect(evt : Event;
                                        human_corruption__isInCorruption : bool)
  let corruptionEffectEid = get_corruption_effect_eid()
  if human_corruption__isInCorruption && corruptionEffectEid == INVALID_ENTITY_ID
    createEntity("corruption_effect")
  elif !human_corruption__isInCorruption
    destroyEntity(corruptionEffectEid)


[es(tag=render, no_order, REQUIRE=corruption_effect)]
def corruption_effect_update(act : ParallelUpdateFrameDelayed;
                             var screen_effect__weight, screen_effect__intensity : float&)
  find_query() <| $ [es(REQUIRE=watchedByPlr)] (human_corruption__relativeIntensity : float)
    screen_effect__weight = human_corruption__relativeIntensity
    screen_effect__intensity = approach(screen_effect__intensity, human_corruption__relativeIntensity, act.dt, 1.0f)
    return true