require app
require ecs
require soundEvent


[es(tag=sound, track=human_jetpack__fuelAlert)]
def jetpack_low_fuel_sound(evt : Event;
                           human_jetpack__fuelAlert : bool;
                           human_jetpack__fuel : float;
                           human_jetpack__maxFuel : float;
                           is_watched_sound : bool;
                           human_jetpack__eid : EntityId)
  if human_jetpack__maxFuel > 0. // ignore ghost jetpack with 0 max fuel
    query(human_jetpack__eid) <| $ [es] (jetpack__active : bool)
      if jetpack__active && human_jetpack__fuelAlert && human_jetpack__fuel > 0. && is_watched_sound && !has(human_jetpack__eid, "ghostJetpack")
        oneshot("am/ui/skeleton_swarm_sensor")


[es(tag=sound, track=vehicle__fuelAlert)]
def vehicle_low_fuel_sound(evt : Event;
                           vehicle__fuelAlert : bool;
                           vehicle__fuelAlertCooldown : float;
                           is_watched_sound : bool;
                           var vehicle__fuelLastAlertAt : float&)
  if is_watched_sound && vehicle__fuelAlert && get_sync_time() - vehicle__fuelAlertCooldown > vehicle__fuelLastAlertAt
    oneshot("am/ui/skeleton_swarm_sensor")
    vehicle__fuelLastAlertAt = get_sync_time()
