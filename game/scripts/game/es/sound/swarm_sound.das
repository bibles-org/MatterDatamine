require ecs
require soundHash
require soundEvent
require sound_utils.modules.sound_player_common
require sound_utils.modules.sound_control_common
require game.events.events
require game.events.events_game
require danetlibs.swarm.main.swarm_events


[es(tag=sound, REQUIRE=swarmDeathSound)]
def swarm_sound_boid_died(evt : EventSomeSwarmBoidDied;
                          sound_control__state : int;
                          @shared_comp human_voice_sound__path : Object;
                          @shared_comp human_voice_sound__descs : Object;
                          sound_tags : Object)
  if have_sound(sound_control__state)
    sound_player_common::play("death", human_voice_sound__path, human_voice_sound__descs, sound_tags, false/*is_watched_sound*/, evt.pos)


[es(tag=sound, REQUIRE=swarmAttackSound)]
def swarm_sound_attack(evt : EventOnEntityHit; eid : EntityId;
                       sound_control__state : int;
                       @shared_comp sound_paths : Object;
                       sound_tags : Object;
                       transform : float3x4)
  if have_sound(sound_control__state) && eid == evt.offender
    sound_player_common::play_path("attack", sound_paths, sound_tags, false/*is_watched_sound*/, transform[3])


[es(tag=sound, track=(sound_control__state, isAlive), REQUIRE=swarmMovementSound)]
def swarm_sound_movement(evt : Event;
                         sound_control__state : int;
                         @shared_comp sound_paths : Object;
                         sound_tags : Object;
                         var sound_event_group : SoundEventGroup&;
                         transform : float3x4;
                         isAlive : bool = true)
  release_all_sounds(sound_event_group)
  if have_sound(sound_control__state) && isAlive
    sound_player_common::play_path("movement", sound_paths, sound_tags, false/*is_watched_sound*/, transform[3], sound_hash("movement"), sound_event_group)
