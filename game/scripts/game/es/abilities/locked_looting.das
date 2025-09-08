require ecs
require game.events.events_game
require game.es.game_effect_macro

[es_game_effect(bool_flag=human__canSeeLootItems, tag=locked_view__lockLootVisibility, invert=true)]
def locked_looting_visibility_es() { pass; }