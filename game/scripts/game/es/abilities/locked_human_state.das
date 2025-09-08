require ecs
require game.events.events_game
require game.es.game_effect_macro

[es_game_effect(bool_flag=human_state__lockCrawl, tag=locked_human_state__lockCrawl)]
def lock_human_crawl_es() { pass; }

[es_game_effect(bool_flag=human_state__lockCrouch, tag=locked_human_state__lockCrouch)]
def lock_human_crouch_es() { pass; }
