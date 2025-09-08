require ecs
require app
require net
require game.events.input_events
require DagorInput


def init(var dev_input__cursorFrom : int&;
         var dev_input__cursorTo : int&)
  //Intended for use with free camera
  dev_input__cursorFrom = int(get_action_handle("Camera.SpeedUp", TYPEGRP_DIGITAL))
  dev_input__cursorTo = int(get_action_handle("Camera.SpeedDown", TYPEGRP_DIGITAL))


def reset(var dev_input__cursorFrom : int&;
          var dev_input__cursorTo : int&)
  dev_input__cursorFrom = int(BAD_ACTION_HANDLE)
  dev_input__cursorTo = int(BAD_ACTION_HANDLE)


[es(tag=input)]
def dev_input__setup(evt : EventDaInputInit;
                     var dev_input__cursorFrom : int&;
                     var dev_input__cursorTo : int&)
  if evt.init
    init(dev_input__cursorFrom,
         dev_input__cursorTo)
  else
    reset(dev_input__cursorFrom,
         dev_input__cursorTo)


[es(tag=input, on_appear)]
def dev_input_init_on_appear(evt : Event;
                             var dev_input__cursorFrom : int&;
                             var dev_input__cursorTo : int&)
  init(dev_input__cursorFrom,
        dev_input__cursorTo)


[es(tag=input, before=(human_common_input_action_triggered_es, human_input_weapon_action_triggered_es))]
def dev_input__cursor_down_es(evt : EventDaInputActionTriggered;
                              input__enabled : bool;
                              dev_input__cursorFrom : int;
                              dev_input__cursorTo : int;
                              cursor__sensitivity : float = 0.25)
  if !input__enabled
    return
  elif int(evt.action) == dev_input__cursorFrom
    query() <| $ [es] (cursor__enabled : bool; var cursor__camDst : float&)
      if cursor__enabled
        cursor__camDst += cursor__sensitivity
  elif int(evt.action) == dev_input__cursorTo
    query() <| $ [es] (cursor__enabled : bool; var cursor__camDst : float&)
      if cursor__enabled
        cursor__camDst -= cursor__sensitivity