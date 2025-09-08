require ecs
require game.events.input_events


[es(tag=input)]
def monster_fligth_input_action_terminated_es(evt : EventDaInputActionTerminated;
                                              human_input__crouch : int;
                                              input__enabled : bool;
                                              monster_flight_mode__enabled : bool;
                                              isInVehicle : bool = false;
                                              var human_input__standState : int&)
  let action = int(evt.action)
  if !input__enabled
    return

  if action == human_input__crouch
    if !isInVehicle && monster_flight_mode__enabled
      human_input__standState = 0

