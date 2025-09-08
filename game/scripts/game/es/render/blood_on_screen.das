require ecs
require math
require DagorMath
require game.utils.hero
require game.events.events_game

[es(tag=render)]
def blood_on_screen_hit_es(evt : EventOnEntityHit;
                           blood_on_screen__baseDuration : float;
                           blood_on_screen__minRelativeDuration : float;
                           blood_on_screen__baseIntensity : float)
  if !getSingletonEntity("blood_on_screen")
    return
  let victim = evt.victim
  let deltaHp = evt.deltaHp
  let blockingDeltaHp = evt.blockingDeltaHp
  let hitDir = evt.hitDir
  if victim != get_controlled_hero() || blockingDeltaHp >= deltaHp
    return
  let damage = deltaHp
  if damage == 0.f || has(victim, "deadEntity")
    return
  let maxHp = get_float(victim, "hitpoints__maxHp") ?? 1.0
  let intensity = saturate(max(0.25f, safediv(damage, maxHp)))
  let duration = blood_on_screen__baseDuration * max(intensity, blood_on_screen__minRelativeDuration)
  broadcastEvent(HitBloodOnScreenRender(direction = hitDir, duration = duration, intensity = blood_on_screen__baseIntensity * intensity, hold = false))
