require ecs
require DngDm
require DagorRandom
require game.events.events_game
require game.events.events_active_matter
require danetlibs.dm.dm_events
require net


[es]
def on_human_fall(evt : EventHumanFall;
                  eid : EntityId;
                  var fallen_state__isAlreadyFell : bool&)
  if !fallen_state__isAlreadyFell // not already exists
    createEntity("human_fallen_animation") <| $(var init)
      set(init, "game_effect__attachedTo", eid)
      set(init, "game_effect__timeToDestroy", evt.duration)
    fallen_state__isAlreadyFell = true


[es(tag=netClient)]
def on_human_fall_client_prediction(evt : EventHumanFallClientPrediction;
                                    eid : EntityId;
                                    var fallen_state__isAlreadyFell : bool&)
  if !fallen_state__isAlreadyFell // not already exists
    createEntity("human_fallen_animation") <| $(var init)
      set(init, "game_effect__attachedTo", eid)
      set(init, "game_effect__timeToDestroy", evt.duration)
    fallen_state__isAlreadyFell = true


[es(on_disappear, REQUIRE=human_fallen_animation)]
def on_human_fallen_animation_disappear(evt : Event;
                                        game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var fallen_state__isAlreadyFell : bool&)
    fallen_state__isAlreadyFell = false


[es(tag=server, on_event)]
def send_fall_on_collision_dmg(evt : CmdCollisionDamage;
                               eid : EntityId;
                               fallen_state__animDuration : float)
  eid |> send_net_event(EventHumanFall(duration = fallen_state__animDuration))


[es(tag=netClient)]
def send_fall_on_collision_dmg_client_prediction(evt : CmdCollisionDamage;
                                                 eid : EntityId;
                                                 fallen_state__animDuration : float)
  eid |> sendEvent(EventHumanFallClientPrediction(duration = fallen_state__animDuration))


[es(tag=server, REQUIRE=human)]
def send_fall_on_melee_dmg(evt : CmdApplyDamage;
                           eid : EntityId;
                           fallen_state__meleeAnimDuration : float)
  if evt.damageType == int(DamageType.DM_MELEE)
    query(evt.offender) <| $ [es] (customizable_melee_attack__isPowerfullAttack : bool;
                                   melee_throw_back__pushForce : float)
      if customizable_melee_attack__isPowerfullAttack
        eid |> sendEvent(CmdPushPhys(vel = evt.hitDir * melee_throw_back__pushForce, push_immunity = 0.0))
        eid |> send_net_event(EventHumanFall(duration = fallen_state__meleeAnimDuration))
