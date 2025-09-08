require ecs
require DngNet
require ecs.common
require DagorInput
require game.events.events_game
require game.events.input_events


def initActions(var human_input__nightVisionDevice : int&)
  human_input__nightVisionDevice = int(get_action_handle("Human.NightVisionDevice", TYPEGRP_DIGITAL))


def resetActions(var human_input__nightVisionDevice : int&)
  human_input__nightVisionDevice = int(BAD_ACTION_HANDLE)


[es(tag=input)]
def human_use_night_vision_device_input_setup(evt : EventDaInputInit;
                                              var human_input__nightVisionDevice : int&)
  if evt.init
    initActions(human_input__nightVisionDevice)
  else
    resetActions(human_input__nightVisionDevice)


[es(tag=input, on_appear)]
def human_use_night_vision_device_input_appear(evt : Event;
                                               var human_input__nightVisionDevice : int&)
  initActions(human_input__nightVisionDevice)


[es(tag=input, on_disappear)]
def human_use_night_vision_device_input_disappear(evt : Event;
                                                  var human_input__nightVisionDevice : int&)
  resetActions(human_input__nightVisionDevice)


[es(tag=input)]
def use_lights_source_input_handler(evt : EventDaInputActionTriggered;
                                    eid : EntityId;
                                    human_input__nightVisionDevice : int)
  if int(evt.action) == human_input__nightVisionDevice
    send_net_event(eid, CmdUseNightVisionDevice())
