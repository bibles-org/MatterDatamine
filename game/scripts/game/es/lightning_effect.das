require ecs
require app
require net
require Dacoll
require math.base
require DagorMath
require DagorRandom
require game.events.events_active_matter


[es(tag=server, no_order)]
def lightning_emitter_act(act : ParallelUpdateFrameDelayed;
                          eid : EntityId;
                          lightning_emitter__enabled : bool = true;
                          lightning_emitter__lightingSpd : float;
                          lightning_emitter__emitTime : float;
                          lightning_emitter__emitRadius : float;
                          lightning_emitter__emitterStartRadius : float;
                          lightning_emitter__offset : float3 = float3(0);
                          transform : float3x4;
                          var lightning_emitter__nextLightingAt : float&)
  if !lightning_emitter__enabled
    return
  if act.curTime < lightning_emitter__nextLightingAt
    return
  lightning_emitter__nextLightingAt = act.curTime + lightning_emitter__emitTime

  let randomTeta = rnd_float(0.0, TWOPI)
  let randomPhi = rnd_float(0.0, TWOPI)
  var sinP, cosP, sinT, cosT : float
  sincos(randomPhi, sinP, cosP)
  sincos(randomTeta, sinT, cosT)
  let fireVector = float3(sinT * cosP, sinT * sinP, cosT)
  let from = (transform * lightning_emitter__offset) + fireVector * lightning_emitter__emitterStartRadius

  var t = lightning_emitter__emitRadius
  var norm : float3
  if traceray_normalized(from, fireVector, t, norm)
    let lifeTime = t / lightning_emitter__lightingSpd
    send_net_event(eid, EventLightningCreated(
      startPos = from,
      direction = fireVector,
      speed = lightning_emitter__lightingSpd,
      lifetime = lifeTime
    ))


[es(tag=gameClient)]
def lightning_effect_create(evt : EventLightningCreated;
                            lightning_emitter__templateName : string;
                            lightning_emitter__clientEnabled : bool = true)
  if !lightning_emitter__clientEnabled
    return
  createEntity(lightning_emitter__templateName) <| $(var init)
    var tm = IDENT_TM
    tm[3] = evt.startPos
    init |> set("transform", tm)
    init |> set("lightning_effect__translationDir", evt.direction)
    init |> set("lightning_effect__translationSpd", evt.speed)
    init |> set("game_effect__timeToDestroy", evt.lifetime)


[es(tag=gameClient, on_appear)]
def lightning_effect_init(evt : Event; var lightning_effect__startedAt : float&)
  lightning_effect__startedAt = get_sync_time()


[es(tag=gameClient, no_order)]
def lightning_effect_act(act : ParallelUpdateFrameDelayed;
                         lightning_effect__translationDir : float3;
                         lightning_effect__translationSpd : float;
                         lightning_effect__canBranch : bool;
                         lightning_effect__startedAt, game_effect__clientDestroyAt : float;
                         lightning_effect__shiftTimeStep, lightning_effect__maxShiftLength : float;
                         lightning_effect__maxBranchesCount : int;
                         lightning_effect__brancheCreationChanceStartFrom : float;
                         lightning_effect__brancheCreationChanceStopAt : float;
                         lightning_effect__branchTemplateName : string;
                         var lightning_effect__curBranchesCount : int&;
                         var lightning_effect__shiftAt : float&;
                         var transform : float3x4&)
  let relativeState = safediv(act.curTime - lightning_effect__startedAt, game_effect__clientDestroyAt - lightning_effect__startedAt)
  var shiftVector : float3
  if act.curTime >= lightning_effect__shiftAt
    lightning_effect__shiftAt = act.curTime + lightning_effect__shiftTimeStep
    var s, c : float
    let angle = rnd_float(0.0, TWOPI)
    sincos(angle, s, c)
    shiftVector = float3(s, 0.0, c)
  let direction = lightning_effect__translationDir + shiftVector * lerp(0.1, lightning_effect__maxShiftLength, relativeState)
  transform[3] += direction * act.dt * lightning_effect__translationSpd

  assume startRelativePos = lightning_effect__brancheCreationChanceStartFrom
  assume stopRelativePos = lightning_effect__brancheCreationChanceStopAt
  if (
       lightning_effect__canBranch
    && lightning_effect__curBranchesCount < lightning_effect__maxBranchesCount
    && (relativeState >= startRelativePos && relativeState < stopRelativePos)
  )
    let chance = cvt(relativeState, startRelativePos, stopRelativePos, 0.01, 1.0)
    if chance >= gfrnd()
      lightning_effect__curBranchesCount += 1
      var t = (game_effect__clientDestroyAt - act.curTime) * lightning_effect__translationSpd
      var norm : float3
      let newDirection = normalize(lightning_effect__translationDir + shiftVector)
      if traceray_normalized(transform[3], newDirection, t, norm)
        let lifeTime = t / lightning_effect__translationSpd
        createEntity(lightning_effect__branchTemplateName) <| $(var init)
          init |> set("transform", transform)
          init |> set("lightning_effect__translationDir", lightning_effect__translationDir)
          init |> set("lightning_effect__translationSpd", lightning_effect__translationSpd)
          init |> set("game_effect__timeToDestroy", lifeTime)
