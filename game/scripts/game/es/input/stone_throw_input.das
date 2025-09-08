require ecs
require app
require DagorInput
require DngNet
require game.events.events_game
require game.events.input_events
require game.es.status_tip_common

def init(var human_stone_throw__input : int&)
  human_stone_throw__input = int(get_action_handle("Human.StoneThrow", TYPEGRP_DIGITAL))


def reset(var human_stone_throw__input : int&)
  human_stone_throw__input = int(BAD_ACTION_HANDLE)


[es(tag=input)]
def stone_throw_input__setup(evt : EventDaInputInit;
                             var human_stone_throw__input : int&)
  if evt.init
    init(human_stone_throw__input)
  else
    reset(human_stone_throw__input)


[es(tag=input, on_appear)]
def stone_throw_init_on_appear(evt : Event;
                               var human_stone_throw__input : int&)
  init(human_stone_throw__input)


[es(on_disappear)]
def stone_throw_deinit_on_disappear(evt : Event;
                                    var human_stone_throw__input : int&)
  reset(human_stone_throw__input)


[es(tag=input, REQUIRE=human_input)]
def stone_throw_input_handler(evt : EventDaInputActionTriggered;
                              eid : EntityId;
                              human_stone_throw__input : int;
                              human_stone_throw__enabled : bool;
                              human_stone_throw__throwTimer : float)
  if human_stone_throw__enabled && int(evt.action) == human_stone_throw__input && human_stone_throw__throwTimer <= 0.f
    send_net_event(eid, RequestStartThrowStone(atTime = get_sync_time()))
