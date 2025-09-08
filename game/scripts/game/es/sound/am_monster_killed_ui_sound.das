require ecs
require soundEvent
require game.events.events_game
require sound_utils.modules.sound_player_common


[es(tag=sound, REQUIRE_NOT=(hero, watchedByPlr))]
def am_monster_killed_ui_sound(evt : EventEntityDied;
                               sound_tags : Object;
                               @shared_comp am_monster_killed_ui_sound_path : Object;
                               transform : float3x4)

  query(evt.offender) <| $ [es(REQUIRE=(hero, watchedByPlr))] ()
    play_path(am_monster_killed_ui_sound_path, sound_tags, false/*is_watched_sound*/, transform[3])
