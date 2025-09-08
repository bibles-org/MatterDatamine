require ecs
require DngNet
require ecs.common
require DagorInput
require game.events.events_game
require game.events.input_events



def initActions(var human_input__flashlight : int&)
  human_input__flashlight = int(get_action_handle("Human.Flashlight", TYPEGRP_DIGITAL))



def resetActions(var human_input__flashlight : int&)
  human_input__flashlight = int(BAD_ACTION_HANDLE)


[es(tag=input)]
def human_use_weapon_flashlight_input_setup(evt : EventDaInputInit;
                                            var human_input__flashlight : int&)
  if evt.init
    initActions(human_input__flashlight)
  else
    resetActions(human_input__flashlight)


[es(tag=input, on_appear)]
def human_use_weapon_flashlight_input_appear(evt : Event;
                                             var human_input__flashlight : int&)
  initActions(human_input__flashlight)


[es(tag=input, on_disappear)]
def human_use_weapon_flashlight_input_disappear(evt : Event;
                                                var human_input__flashlight : int&)
  resetActions(human_input__flashlight)

