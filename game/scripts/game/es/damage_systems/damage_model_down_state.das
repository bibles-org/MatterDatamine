require ecs
require game.events.events_game
require DngNet
require game.events.events
require DagorRandom
require game.es.pain_common


def private revive_entity(eid : EntityId; revive_by_timer = false)
  query(eid) <| $ [es] (var isDowned : bool&)
    if isDowned
      isDowned = false
      send_net_event(eid, EventEntityRevived(reviveByTimer = revive_by_timer))


[es(tag=server, no_order, REQUIRE_NOT=hitpoints__hp)]
def human_damage_model_down_state_act(info : UpdateStageInfoAct;
                                      eid : EntityId;
                                      hitpoints__downedEndTime : float;
                                      isDowned : bool)
  if !isDowned || info.curTime < hitpoints__downedEndTime
    return
  revive_entity(eid, true)


[es(tag=server, on_appear, REQUIRE=painkillerEffect)]
def human_damage_model_down_state_painkiller_effect(evt : Event;
                                                    game_effect__attachedTo : EntityId)
  revive_entity(game_effect__attachedTo)


[es(tag=server, on_appear, REQUIRE=damageModelEffectDownState, after=damage_model_effect_down_state)]
def downed_effect_set_car_animation(evt : Event;
                                    eid, game_effect__attachedTo : EntityId;
                                    downed_effect__passengerAnims, downed_effect__driverAnims : StringList;
                                    downed_effect__vehicleAnimTemplate : string)
  query(game_effect__attachedTo) <| $ [es] (isInVehicle, isDriver : bool)
    if isInVehicle
      let anim = string(isDriver ?
          downed_effect__driverAnims[grnd() % length(downed_effect__driverAnims)] :
          downed_effect__passengerAnims[grnd() % length(downed_effect__passengerAnims)])
      remote_add_sub_template(eid, downed_effect__vehicleAnimTemplate) <| $(var init : ComponentsInitializer)
        init |> set("game_effect__forceAnimState", anim)


[es(tag=server, track=isInVehicle)]
def remove_vehicle_downed_anim_on_exit_vehicle(evt : Event;
                                               isInVehicle : bool;
                                               eid aka hero_eid : EntityId)
  if !isInVehicle
    query() <| $ [es] (game_effect__attachedTo, eid aka eff_eid : EntityId;
                       downed_effect__templateName : string)
      if game_effect__attachedTo == hero_eid
        remote_remove_sub_template(eff_eid, downed_effect__templateName)


[es]
def apply_pain_on_revive_by_timer(evt : EventEntityRevived;
                                  eid : EntityId)
  if evt.reviveByTimer
    let maxPainProgress = 1f
    add_pain_progress(eid, maxPainProgress)