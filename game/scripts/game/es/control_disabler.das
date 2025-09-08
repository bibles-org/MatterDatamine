require ecs
require game.events.events_game
require game.es.game_effect_macro

[es_game_effect(bool_flag=human_net_phys__uncontrollable, tag=game_effect__uncontrollable)]
def control_disabler_es() { pass; }
