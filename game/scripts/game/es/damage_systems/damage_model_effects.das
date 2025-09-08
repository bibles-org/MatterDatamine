require ecs
require game.es.damage_systems.damage_model_common
require game.events.events
require HumanPhys
require AnimV20
require DngDm
require DngHuman
require app
require DngNet
require game.utils.hero
require game.es.pain_common
require DaWeapons
require game.events.events_active_matter
require game.events.events_game
require danetlibs.weapons.melee_events
require game.es.entity_mods_common


[es(tag=server, on_appear, REQUIRE=damageModelEffectImmediateDeath)]
def damage_model_effect_immediate_death(evt : Event;
                                        eid, game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (death_desc__damageType : int;
                                            death_desc__gunPropsId : int;
                                            death_desc__shellId : int;
                                            death_desc__collNodeId : int;
                                            death_desc__victimTeam : int;
                                            death_desc__offenderTeam : int;
                                            var hitpoints__lastOffender : EntityId&;
                                            var hitpoints__lastOffenderPlayer : EntityId&;
                                            hitpoints__lastVictimPlayer : EntityId;
                                            lastCriticalOffender : EntityId;
                                            var isAlive : bool&;
                                            var isDowned : bool&)
    // it is possible with shotgun to add multiple damageModelEffectImmediateDeath effects
    // so we need to check if entity is already dead
    if !isAlive
      return
    isAlive = false
    isDowned = false
    human_damage_model_kill_entity(game_effect__attachedTo,
                                   death_desc__damageType,
                                   death_desc__gunPropsId,
                                   death_desc__shellId,
                                   death_desc__collNodeId,
                                   death_desc__victimTeam,
                                   death_desc__offenderTeam,
                                   hitpoints__lastOffender,
                                   hitpoints__lastOffenderPlayer,
                                   hitpoints__lastVictimPlayer,
                                   lastCriticalOffender)
  destroyEntity(eid)


[es(tag=server, on_appear, REQUIRE=damageModelEffectDownState)]
def damage_model_effect_down_state(evt : Event;
                                   eid, game_effect__attachedTo : EntityId)
  if has_pain_immunity(game_effect__attachedTo)
    destroyEntity(eid)
    return
  query(game_effect__attachedTo) <| $ [es] (hitpoints__downedTimer : float;
                                            hitpoints__lastOffender : EntityId;
                                            hitpoints__lastOffenderPlayer : EntityId;
                                            entity_mod_values : Object;
                                            human_net_phys__isSwimming : bool = false;
                                            ignoreDownState : Tag const?;
                                            var isDowned : bool&;
                                            var hitpoints__downedEndTime : float&;
                                            var lastCriticalOffender : EntityId&)
    if ignoreDownState != null
      destroyEntity(eid)
      return

    if human_net_phys__isSwimming
      destroyEntity(eid)
      return
    isDowned = true
    let shockTime = hitpoints__downedTimer - get_mod_value("shockReduction", entity_mod_values, 0.0)
    hitpoints__downedEndTime = get_sync_time() + max(0.0, shockTime)
    send_net_event(eid, EventEntityDowned(offender = hitpoints__lastOffender))
    broadcastEvent(EventAnyEntityDowned(victim = eid, offender = hitpoints__lastOffender))
    lastCriticalOffender = hitpoints__lastOffenderPlayer

[es(tag=server, on_event=(EventEntityRevived, EventEntityDied))]
def destroy_downed_effect_on_revived_or_died(evt : Event;
                                             isDowned, isAlive : bool;
                                             eid aka hero_eid : EntityId)
  if !isDowned || !isAlive
    query() <| $ [es(REQUIRE=damageModelEffectDownState)] (game_effect__attachedTo, eid aka eff_eid : EntityId)
      if game_effect__attachedTo == hero_eid
        destroyEntity(eff_eid)


// TODO: rework to state
[es(before=after_net_phys_sync, after=human_weap_phys_es, REQUIRE=damage_model_effect__lockAim)]
def damage_model_effect_lock_aim(info : ParallelUpdateFrameDelayed;
                                 game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var human_net_phys : HumanActor)
    assume ct = human_net_phys.phys.currentState
    human_phys_state_set_can_aim(ct, false)


// TODO: make mult mods for human_coll_damage__minDmgSpd
[es(on_appear)]
def damage_model_effect_collision_damage_speed_mult_apply(evt : Event;
                                                          game_effect__attachedTo : EntityId;
                                                          damage_model_effect__collisionDamageSpeedMult : float)
  query(game_effect__attachedTo) <| $ [es] (var human_coll_damage__minDmgSpd : float&)
    human_coll_damage__minDmgSpd *= damage_model_effect__collisionDamageSpeedMult

[es(on_disappear)]
def damage_model_effect_collision_damage_speed_mult_reset(evt : Event;
                                                          game_effect__attachedTo : EntityId;
                                                          damage_model_effect__collisionDamageSpeedMult : float)
  query(game_effect__attachedTo) <| $ [es] (var human_coll_damage__minDmgSpd : float&)
    human_coll_damage__minDmgSpd /= damage_model_effect__collisionDamageSpeedMult


[es(after=human_phys_es, before=after_net_phys_sync, REQUIRE_NOT=disableUpdate)]
def damage_model_effect_lock_hold_breath(evt : CmdPostPhysUpdate;
                                         eid : EntityId;
                                         var human_net_phys : HumanActor&)
  find_query() <| $ [es(REQUIRE=damage_model_effect__lockHoldBreath)] (game_effect__attachedTo : EntityId)
    if game_effect__attachedTo == eid
      set_is_hold_breath(human_net_phys.phys.currentState, false)
    return game_effect__attachedTo == eid


[es(before=pain_intensity, REQUIRE=damageModelEffectActivatorPainOnSprint)]
def damage_model_effect_activator_pain_on_sprint(info : ParallelUpdateFrameDelayed;
                                                 game_effect__attachedTo : EntityId;
                                                 damage_model_effect__addPainProgress : float)
  query(game_effect__attachedTo) <| $ [es(REQUIRE_NOT=deadEntity)] (human_net_phys : HumanActor)
    let isSprinting = human_net_phys.phys.currentState.moveState == HUMoveState.EMS_SPRINT
    if isSprinting
      add_pain_progress(game_effect__attachedTo, damage_model_effect__addPainProgress * info.dt)


[es(before=pain_intensity, REQUIRE=damageModelEffectActivatorPainOnLadder)]
def damage_model_effect_activator_pain_on_ladder(info : ParallelUpdateFrameDelayed;
                                                 game_effect__attachedTo : EntityId;
                                                 damage_model_effect__addPainProgress : float)
  query(game_effect__attachedTo) <| $ [es(REQUIRE_NOT=deadEntity)] (human_net_phys : HumanActor)
    let isAttachedToLadder = human_net_phys.phys.currentState.isAttachedToLadder
    if isAttachedToLadder
      add_pain_progress(game_effect__attachedTo, damage_model_effect__addPainProgress * info.dt)


[es(before=pain_intensity, REQUIRE=damageModelEffectActivatorPainOnClimb)]
def damage_model_effect_activator_pain_on_climb(info : ParallelUpdateFrameDelayed;
                                                game_effect__attachedTo : EntityId;
                                                damage_model_effect__addPainProgress : float)
  query(game_effect__attachedTo) <| $ [es(REQUIRE_NOT=deadEntity)] (human_net_phys__isClimbing : bool)
    if human_net_phys__isClimbing
      add_pain_progress(game_effect__attachedTo, damage_model_effect__addPainProgress * info.dt)


[es(before=pain_intensity, REQUIRE=damageModelEffectActivatorPainOnAim)]
def damage_model_effect_activator_pain_on_aim(info : ParallelUpdateFrameDelayed;
                                              game_effect__attachedTo : EntityId;
                                              damage_model_effect__addPainProgress : float)
  query(game_effect__attachedTo) <| $ [es(REQUIRE_NOT=deadEntity)] (human_net_phys__isAiming : bool)
    if human_net_phys__isAiming
      add_pain_progress(game_effect__attachedTo, damage_model_effect__addPainProgress * info.dt)


[es(on_appear)]
def damage_model_effect_injured_animation_apply(evt : Event;
                                                game_effect__attachedTo : EntityId;
                                                damage_model_effect__injuredVarName : string)
  query(game_effect__attachedTo) <| $ [es] (var animchar : AnimcharBaseComponent)
    let paramId = *animchar.animGraph |> anim_graph_getParamId(damage_model_effect__injuredVarName, int(PT_ScalarParam))
    if paramId >= 0
      *animchar.animState |> anim_state_holder_setParam(paramId, 1.0)


[es(on_disappear)]
def damage_model_effect_injured_animation_reset(evt : Event;
                                                game_effect__attachedTo : EntityId;
                                                damage_model_effect__injuredVarName : string)
  query(game_effect__attachedTo) <| $ [es] (var animchar : AnimcharBaseComponent)
    let paramId = *animchar.animGraph |> anim_graph_getParamId(damage_model_effect__injuredVarName, int(PT_ScalarParam))
    if paramId >= 0
      *animchar.animState |> anim_state_holder_setParam(paramId, 0.0)


[es(after=after_guns_update_sync, before=clear_gun_launch_events_es, REQUIRE=damageModelEffectActivatorPainOnShoot)]
def damage_model_effect_activator_pain_on_shoot(info : ParallelUpdateFrameDelayed;
                                                game_effect__attachedTo : EntityId;
                                                damage_model_effect__addPainProgress : float)
  query(game_effect__attachedTo) <| $ [es(REQUIRE_NOT=deadEntity)] (human_weap__currentGunEid : EntityId;
                                                                    human_attached_gun__attachedGunEid = INVALID_ENTITY_ID)
    let currentGunEid  = human_weap__currentGunEid
    if !currentGunEid && !human_attached_gun__attachedGunEid
      return
    let isAttachedGun = !!human_attached_gun__attachedGunEid
    let gunEid = isAttachedGun ? human_attached_gun__attachedGunEid : currentGunEid
    query(gunEid) <| $ [es] (gun_launch_events : GunLaunchEvents)
      if length(gun_launch_events.launchEvents) > 0
        add_pain_progress(game_effect__attachedTo, damage_model_effect__addPainProgress * info.dt)


[es(REQUIRE_NOT=twoHandedMeleeWeapon)]
def damage_model_effect_activator_pain_on_melee(evt : EventMeleeAction;
                                                gun__owner : EntityId)
  find_query() <| $ [es(REQUIRE=damageModelEffectActivatorPainOnMelee)] (game_effect__attachedTo : EntityId;
                                                                         damage_model_effect__addPainProgress : float)
    if gun__owner == game_effect__attachedTo
      add_pain_progress(gun__owner, damage_model_effect__addPainProgress)
      return true
    return false


[es(REQUIRE=twoHandedMeleeWeapon)]
def damage_model_effect_activator_pain_on_two_handed_melee(evt : EventMeleeAction;
                                                           gun__owner : EntityId)
  find_query() <| $ [es(REQUIRE=damageModelEffectActivatorPainOnTwoHandedMelee)] (game_effect__attachedTo : EntityId;
                                                                                  damage_model_effect__addPainProgress : float)
    if gun__owner == game_effect__attachedTo
      add_pain_progress(gun__owner, damage_model_effect__addPainProgress)
      return true
    return false


[es(track=human_net_phys__isInAir)]
def damage_model_effect_activator_pain_on_landing(evt : Event;
                                                  eid : EntityId;
                                                  human_net_phys__isInAir : bool;
                                                  human_net_phys : HumanActor)
  if human_net_phys__isInAir
    return
  let prevVel = length(human_net_phys.phys.previousState.velocity)
  query() <| $ [es(REQUIRE=damageModelEffectActivatorPainOnLanding)] (game_effect__attachedTo : EntityId;
                                                                      damage_model_effect__addPainProgress : float;
                                                                      damage_model_effect__velCondition : float)
    if eid == game_effect__attachedTo && prevVel >= damage_model_effect__velCondition
      add_pain_progress(eid, damage_model_effect__addPainProgress)