require ecs
require DagorInput
require game.events.input_events


def init_actions(var human_use_emote_input__useEmote : int&)
  human_use_emote_input__useEmote = int(get_action_handle("Human.UseEmote", TYPEGRP_DIGITAL))


def reset_actions(var human_use_emote_input__useEmote : int&)
  human_use_emote_input__useEmote = int(BAD_ACTION_HANDLE)


[es(on_appear)]
def human_use_emote_init_es(evt : Event;
                            var human_use_emote_input__useEmote : int&)
  init_actions(human_use_emote_input__useEmote)


[es(on_disappear)]
def human_use_emote_deinit_es(evt : Event;
                              var human_use_emote_input__useEmote : int&)
  reset_actions(human_use_emote_input__useEmote)


[es(tag=gameClient)]
def human_use_emote_input_es(evt : EventDaInputInit;
                             input__enabled : bool;
                             var human_use_emote_input__useEmote : int&)
  if input__enabled
    if evt.init
      init_actions(human_use_emote_input__useEmote)
    else
      reset_actions(human_use_emote_input__useEmote)
