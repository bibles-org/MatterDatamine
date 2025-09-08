require ecs
require DagorInput
require game.events.input_events


def init(var spectator_input__prev, spectator_input__next : int&)
  spectator_input__prev = get_action_handle("Spectator.Prev", TYPEGRP_DIGITAL) |> int()
  spectator_input__next = get_action_handle("Spectator.Next", TYPEGRP_DIGITAL) |> int()
  activate_action_set(get_action_set_handle("Spectator"), true)



def reset(var spectator_input__prev, spectator_input__next : int&)
  spectator_input__prev = int(BAD_ACTION_HANDLE)
  spectator_input__next = int(BAD_ACTION_HANDLE)
  activate_action_set(get_action_set_handle("Spectator"), false)

[es(tag=input, on_appear)]
def spectator_input_appear_es(evt : Event; var spectator_input__prev, spectator_input__next : int&)
  init(spectator_input__prev, spectator_input__next)

[es(tag=input)]
def spectator_input_input_es(evt : EventDaInputInit; var spectator_input__prev, spectator_input__next : int&)
  if evt.init
    init(spectator_input__prev, spectator_input__next)
  else
    reset(spectator_input__prev, spectator_input__next)

[es(tag=input, on_disappear)]
def spectator_input_remove(evt : Event; var spectator_input__prev, spectator_input__next : int&)
  reset(spectator_input__prev, spectator_input__next)
