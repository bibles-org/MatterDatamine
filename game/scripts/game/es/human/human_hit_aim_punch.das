require ecs
require app
require math.base
require game.utils.hero
require game.events.events_game
require game.events.events_active_matter
require HumanPhys
require DngHuman
require DagorSystem
require DagorMath
require DagorRandom
require DaWeaponProps
require DaWeapons
require DngDm

// human_aim_punch event structure - float3
// [0](float) - time
// [1](float) - strength.x
// [2](float) - strength.y

def get_punch_time(punch : float3&) : float
  return punch.x

def get_punch_strength(punch : float3&) : float2
  return punch.yz

[es]
def human_aim_punch_es(info : ParallelUpdateFrameDelayed;
                       human_aim_punch__queuedEvents : Point3List;
                       var human_net_phys : HumanActor&;
                       var human_aim_punch__curPower : float&;
                       human_aim_punch__powerRestoreSpeed : float)
  for punch in human_aim_punch__queuedEvents
    let punchTime = get_punch_time(punch)
    if (info.curTime - info.dt < punchTime && info.curTime >= punchTime)
      let punchStrength = get_punch_strength(punch)
      human_net_phys.phys.currentState.gunAimOffset += punchStrength
  human_aim_punch__curPower = move_to_scalar(human_aim_punch__curPower, 0f, info.dt, human_aim_punch__powerRestoreSpeed)

[es(tag = server)]
def human_aim_punch_authority_es(info : ParallelUpdateFrameDelayed;
                                 var human_aim_punch__queuedEvents : Point3List)
  let eventsCount = human_aim_punch__queuedEvents |> length()
  var i = eventsCount - 1
  while i >= 0
    let punch = human_aim_punch__queuedEvents[i]
    let punchTime = get_punch_time(punch)
    if info.curTime - 1.0 > punchTime
      human_aim_punch__queuedEvents |> erase(i)
    i--

[es(tag = server)]
def human_aim_punch_events_es(evt : EventOnEntityHit;
                              eid : EntityId;
                              var human_aim_punch__curPower : float&;
                              human_aim_punch__strengthDamageAdaptationMultiplier : float;
                              human_aim_punch__timeOffset : float = 0.1;
                              human_aim_punch__hpMult : float = 2.0;
                              human_aim_punch__maxStrength : float = 15.0;
                              human_aim_punch__punchesMinInterval : float = 0.1;
                              human_aim_punch__punchesRepeatMult : float = 0.5;
                              entity_mods__moreStabilityWhenHitMult : float = 0.0;
                              var human_aim_punch__queuedEvents : Point3List;
                              var human_aim_punch__lastPunchTime : float&)
  let damageDesc = evt
  let victim = evt.victim
  if eid != victim || damageDesc.damageType == int(DamageType.DM_ZONE)
    return

  let curTime = get_sync_time()
  let time = curTime + human_aim_punch__timeOffset
  var damageStrength = 0f
  if damageDesc.deltaHp > 0.0
    damageStrength = deg_to_rad(min(damageDesc.deltaHp * human_aim_punch__hpMult, human_aim_punch__maxStrength))
  else
    damageStrength = deg_to_rad(min(damageDesc.blockingDeltaHp * human_aim_punch__hpMult, human_aim_punch__maxStrength))

  let stabilityStrMult = 1.0 - clamp(entity_mods__moreStabilityWhenHitMult, 0.0, 1.0)
  let strengthFromDamage = damageStrength * stabilityStrMult
  var strength = max(strengthFromDamage - human_aim_punch__curPower * human_aim_punch__strengthDamageAdaptationMultiplier, 0f)
  if time - human_aim_punch__lastPunchTime > human_aim_punch__punchesMinInterval
    human_aim_punch__lastPunchTime = time
  else
    strength *= human_aim_punch__punchesRepeatMult

  let dir = gfrnd() * TWOPI
  var dirSin, dirCos : float
  sincos(dir, dirSin, dirCos)

  human_aim_punch__queuedEvents |> push(float3(time, dirSin * strength, dirCos * strength))
  human_aim_punch__curPower = max(human_aim_punch__curPower, strengthFromDamage)