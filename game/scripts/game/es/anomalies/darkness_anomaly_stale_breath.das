require ecs
require HumanPhys
require DngHuman


[es(on_appear)]
def darkness_anomaly_stale_breath_appear(act : Event; game_effect__attachedTo : EntityId;
                                         darkness_anomaly__staleBreathAvailableTime : float)
  query(game_effect__attachedTo) <| $ [es] (human_breath__maxHoldBreathTime : float;
                                            var human_net_phys : HumanActor; var human_breath__timer : float&)
    set_is_hold_breath(human_net_phys.phys.currentState, true)
    human_breath__timer = max(0f, human_breath__maxHoldBreathTime - darkness_anomaly__staleBreathAvailableTime)


[es(REQUIRE=darkness_anomaly__staleBreathAvailableTime, before=human_breath_timer_es)]
def darkness_anomaly_stale_breath(act : UpdateStageInfoAct; game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var human_breath__staleBreath : bool&)
    human_breath__staleBreath = true


[es(REQUIRE=darkness_anomaly__staleBreathAvailableTime, on_disappear)]
def darkness_anomaly_stale_breath_disappear(act : Event; game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (var human_net_phys : HumanActor; var human_breath__staleBreath : bool&)
    human_breath__staleBreath = false
    set_is_hold_breath(human_net_phys.phys.currentState, false)
