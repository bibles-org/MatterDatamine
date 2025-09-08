require ecs
require Ballistics
require game.events.events
require game.events.events_game


[es(REQUIRE=npysPushableByBullet)]
def pushback_from_projectile(evt : EventOnProjectileHit;
                             eid : EntityId;
                             nphys__mass : float)
  query(evt.projectileEid) <| $ [es] (gunEid : EntityId; projectile_ballistics : ProjectileBallistics)
    query(gunEid) <| $ [es] (gun__projectileExtraImpulse : float)
      let pushbackVelocity = normalize(projectile_ballistics.state.vel) * gun__projectileExtraImpulse / nphys__mass
      sendEvent(eid, CmdPushPhys(vel = pushbackVelocity, push_immunity = 0.f))
