require ecs
require game.es.ecs_common
require game.events.events
require game.events.events_game
require DagorMath
require DngHuman
require game.es.entity_mods_common


[es(REQUIRE_NOT=disableUpdate)]
def human_collider_damage(evt : CmdPostPhysUpdate;
                          eid : EntityId;
                          human_net_phys : HumanActor;
                          transform : float3x4;
                          isAlive : bool;
                          human_coll_damage__minDmgSpd : float;
                          human_coll_damage__dmgPow : float;
                          human_coll_damage__hpCoeff : float;
                          human_coll_damage__minFallDmgVal : float;
                          human_coll_damage__minFallDmgDirDot : float = 0.5;
                          human_coll_damage__minHpLevel : float;
                          human_dodge__isDodging : bool = false;
                          entity_mod_values : Object const?;
                          entity_mods__lessFallDmgMult : float = 1.0f;
                          entity_mods__lessCollDmgMult : float = 1.0f;
                          hitpoints__hp = 0f;
                          heroForPlayer : Tag const?)
  if !evt.isForReal
    return

  var minDmgSpd = human_coll_damage__minDmgSpd
  if entity_mod_values != null
    minDmgSpd *= get_mod_value("fallDamageSpeedMult", *entity_mod_values, 1.0)

  let minDmgSpdSquare = minDmgSpd * minDmgSpd
  let spdSummaryDiffLengthSq = length_sq(human_net_phys.phys.currentState.spdSummaryDiff)
  if isAlive && spdSummaryDiffLengthSq > minDmgSpdSquare
    let dmgSpd = sqrt(spdSummaryDiffLengthSq)
    let dmgDir = human_net_phys.phys.currentState.spdSummaryDiff / dmgSpd
    let isFallDamage = dot(dmgDir, -human_net_phys.phys.currentState.gravDirection) >= human_coll_damage__minFallDmgDirDot

    if !isFallDamage && human_dodge__isDodging
      // Ignore dodge damage
      return

    var damage = human_coll_damage__minFallDmgVal
    damage += pow(dmgSpd - minDmgSpd, human_coll_damage__dmgPow) * human_coll_damage__hpCoeff

    if isFallDamage
      damage *= entity_mods__lessFallDmgMult
    damage *= entity_mods__lessCollDmgMult

    if hitpoints__hp > 0.0
      damage = min(damage, hitpoints__hp - human_coll_damage__minHpLevel)

    if damage > 0.f
      sendEvent(eid, CmdCollisionDamage(damage = damage, pos = transform[3], offender = eid))

      // TODO: temporary debug log
      // to investigate bug with window-killers
      if heroForPlayer != null
        print("[HERO] [COLLISION DAMAGE]
eid={get_entity_info(eid)}
damage={damage}
isFallDamage={isFallDamage}
human_dodge__isDodging={human_dodge__isDodging}
human_coll_damage__minDmgSpd={human_coll_damage__minDmgSpd}
human_coll_damage__dmgPow={human_coll_damage__dmgPow}
pos={transform[3]}
currentState.velocity={human_net_phys.phys.currentState.velocity}
previousState.velocity={human_net_phys.phys.previousState.velocity}
currentState.spdSummaryDiff={human_net_phys.phys.currentState.spdSummaryDiff}
previousState.spdSummaryDiff={human_net_phys.phys.previousState.spdSummaryDiff}
currentState.walkNormal={human_net_phys.phys.currentState.walkNormal}
previousState.walkNormal={human_net_phys.phys.previousState.walkNormal}
currentState.standingVelocity={human_net_phys.phys.currentState.standingVelocity}
previousState.standingVelocity={human_net_phys.phys.previousState.standingVelocity}
currentState.deltaVelIgnoreAmount={human_net_phys.phys.currentState.deltaVelIgnoreAmount}
previousState.deltaVelIgnoreAmount={human_net_phys.phys.previousState.deltaVelIgnoreAmount}")