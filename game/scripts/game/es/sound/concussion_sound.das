require ecs
require soundHash
require soundEvent
require sound_utils.modules.sound_player_common

[es(tag=sound, REQUIRE=concussionSoundSuppression, on_appear)]
def concussion_sound_created(evt : Event; game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (isAlive : bool;
                                            @shared_comp human_voice_sound__path : Object;
                                            @shared_comp human_voice_sound__descs : Object;
                                            sound_tags : Object;
                                            is_watched_sound : bool;
                                            isDowned : bool;
                                            transform : float3x4;
                                            var sound_event_group : SoundEventGroup&)
    if is_watched_sound && isAlive && !isDowned && !has_sound(sound_event_group, sound_hash("concussed"))
      sound_player_common::play("concussed", human_voice_sound__path, human_voice_sound__descs, sound_tags, is_watched_sound, transform[3], sound_hash("concussed"), sound_event_group)

[es(tag=sound, REQUIRE=concussionSoundSuppression, on_disappear)]
def concussion_sound_remove(evt : Event; game_effect__attachedTo : EntityId; concussion__replaced : bool)
  if !concussion__replaced
    query(game_effect__attachedTo) <| $ [es] (var sound_event_group : SoundEventGroup&)
      reject_sound(sound_event_group, sound_hash("concussed"))

def is_concussed(eid : EntityId)
  return find_query() <| $ [es(REQUIRE=concussionSoundSuppression)] (game_effect__attachedTo : EntityId)
    return game_effect__attachedTo == eid

[es(tag=sound, track=(is_watched_sound, isAlive, isDowned))]
def concussion_sound_track(evt : Event;
                           eid : EntityId;
                           @shared_comp human_voice_sound__path : Object;
                           @shared_comp human_voice_sound__descs : Object;
                           sound_tags : Object;
                           is_watched_sound : bool;
                           isAlive : bool;
                           isDowned : bool;
                           transform : float3x4;
                           var sound_event_group : SoundEventGroup&)
  reject_sound(sound_event_group, sound_hash("concussed"))
  if is_watched_sound && isAlive && !isDowned && is_concussed(eid)
    sound_player_common::play("concussed", human_voice_sound__path, human_voice_sound__descs, sound_tags, is_watched_sound, transform[3], sound_hash("concussed"), sound_event_group)
