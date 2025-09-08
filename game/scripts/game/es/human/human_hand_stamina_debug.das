options no_aot
require ecs
require strings
require DngHuman
require DagorConsole
require game.es.net_console_macro
require game.utils.net_utils


def human_hand_stamina_set(eid : EntityId;
                           value : bool)
  query(eid) <| $ [es] (human_hand_stamina__maxStamina : float;
                        var human_hand_stamina__enabled : bool&;
                        var human_hand_stamina__stamina : float&)
    human_hand_stamina__enabled = value
    human_hand_stamina__stamina = human_hand_stamina__maxStamina


[net_console_cmd(name="am.hand_stamina_set_server")]
def console_human_hand_stamina_set_server(@net_hero eid : EntityId;
                                          value : bool = true)
  human_hand_stamina_set(eid, value)


[console_cmd(name="am.hand_stamina_set")]
def console_human_hand_stamina_set(value : bool)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    human_hand_stamina_set(eid, value)
    if !is_server()
      exec_server_cmd("am.hand_stamina_set_server :hero: {value}")

