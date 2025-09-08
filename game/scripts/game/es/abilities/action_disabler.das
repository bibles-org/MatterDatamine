require ecs
require game.events.events_game
require game.es.game_effect_macro


[es_game_effect(bool_flag=actions__enabled, tag=game_effect__disableActions, invert=true)]
def lock_actions_use_es() { pass; }

[es_game_effect(bool_flag=human_use_object__enabled, tag=game_effect__disableUse, invert=true)]
def lock_use_action_use_es() { pass; }

[es_game_effect(bool_flag=isShootingAllowed, tag=game_effect__disableShooting, invert=true)]
def lock_shooting_es() { pass; }

[es_game_effect(bool_flag=isMeleeAllowed, tag=game_effect__disableMelee, invert=true)]
def lock_melee_es() { pass; }
