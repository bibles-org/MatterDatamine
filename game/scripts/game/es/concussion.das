require ecs
require app
require DngDm
require DagorMath
require DngHuman
require game.events.events_game
require game.events.events_active_matter
require game.es.concussion_common
require game.utils.hero
require DaWeaponProps
require BallisticsProps
require DaWeapons
require Grid
require GridCollision
require AnimV20
require GeomNodeTree

[es(tag=server, no_order)]
def concussion_timer(info : ParallelUpdateFrameDelayed;
                     eid : EntityId;
                     concussion__startedAtTime : float;
                     concussion__duration : float)
  if info.curTime > concussion__startedAtTime + concussion__duration
    destroyEntity(eid)

[es(tag=server, on_appear)]
def concussion_init_timer(evt : Event; var concussion__startedAtTime : float&)
  concussion__startedAtTime = get_sync_time()

[es(no_order, REQUIRE=concussionHandsShake)]
def concussion_hands_shake_fade(info : ParallelUpdateFrameDelayed;
                                game_effect__attachedTo : EntityId;
                                concussion__startedAtTime : float;
                                concussion__duration : float;
                                concussion__handsShakeFadeTime : float;
                                concussion__handsShakeMagnitude : float)
  let endAt = concussion__startedAtTime + concussion__duration
  let fadeMult = cvt(info.curTime, endAt - concussion__handsShakeFadeTime, endAt, 1.0, 0.0)
  query(game_effect__attachedTo) <| $ [es] (var human_net_phys : HumanActor)
    human_net_phys.phys.currentState.handsShakeMagnitude = concussion__handsShakeMagnitude * fadeMult

[es(tag=server, REQUIRE=human)]
def on_hit_concussion(evt : EventOnEntityHit; eid : EntityId; isAlive : bool; concussion__template : string)
  if evt.victim != eid || !isAlive
    return
  if evt.damageType == int(DamageType.DM_EXPLOSION)
    enable_concussion_affect(eid, concussion__template)
  elif evt.damageType == int(DamageType.DM_MELEE) || evt.damageType == int(DamageType.DM_BACKSTAB)
    let actionPropId = evt.actionPropsId
    if actionPropId >= 0
      melee_get_props(actionPropId) <| $(meleeProps : MeleeProps)
        if meleeProps.concussion
          enable_concussion_affect(eid, concussion__template)

[es(tag=server, track=isAlive)]
def on_death_disable_concussion(evt : Event; eid : EntityId; isAlive : bool)
  if !isAlive
    disable_concussion_affect(eid)

[es(REQUIRE=concussionHandsShake, on_appear)]
def concussion_hands_shake_create(evt : Event;
                                  game_effect__attachedTo : EntityId;
                                  concussion__handsShakeMagnitude : float;
                                  concussion__handsShakeSpeedMult : float)
  query(game_effect__attachedTo) <| $ [es] (var human_net_phys : HumanActor)
    human_net_phys.phys.currentState.handsShakeMagnitude = concussion__handsShakeMagnitude
    human_net_phys.phys.currentState.handsShakeSpeedMult = concussion__handsShakeSpeedMult

[es(REQUIRE=concussionHandsShake, on_disappear)]
def concussion_hands_shake_remove(evt : Event; game_effect__attachedTo : EntityId; concussion__replaced : bool)
  if concussion__replaced
    return
  query(game_effect__attachedTo) <| $ [es] (var human_net_phys : HumanActor)
    human_net_phys.phys.currentState.handsShakeMagnitude = 0.0
    human_net_phys.phys.currentState.handsShakeSpeedMult = 1.0

[es(tag=gameClient, REQUIRE=concussionScreenEffect, on_appear)]
def concussion_screen_effect_create(evt : Event; game_effect__attachedTo : EntityId)
  setOptional(game_effect__attachedTo, "hasConcussedVision", true)

[es(tag=gameClient, REQUIRE=concussionScreenEffect, on_disappear)]
def concussion_screen_effect_remove(evt : Event; game_effect__attachedTo : EntityId)
  setOptional(game_effect__attachedTo, "hasConcussedVision", false)
