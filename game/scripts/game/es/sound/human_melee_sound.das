require ecs
require app
require ecs.safe
require ecs.common
require soundEvent
require soundHash
require sound_utils.modules.sound_player_common
require game.events.sound_events
require DagorRandom
require strings


def play_sound(name : string;
               path_obj : Object;
               sound_tags : Object;
               delay : float;
               is_watched_sound : bool;
               var sound_event_group : SoundEventGroup&;
               transform : float3x4)
  var path : string
  if sound_player_common::get_option_path(path_obj, sound_tags, is_watched_sound, path)
    let handle = soundEvent::delayed_play(name, apply_watched_prefix(path, is_watched_sound), transform[3], delay)
    add_sound(sound_event_group, sound_hash(""), handle)


def human_melee_sound_delay_debug(delay : int;
                                  weapon : Object const?;
                                  sound_tags : Object;
                                  is_watched_sound : bool;
                                  var sound_event_group : SoundEventGroup&;
                                  transform : float3x4)
  play_sound("", *weapon, sound_tags, float(delay) * 0.001, is_watched_sound, sound_event_group, transform)


def take_a_chance(chance : int)
  return rnd_int(1, 100) <= chance


[es(tag=sound)]
def human_melee_sound_irq(evt : CmdSoundMeleeIrq;
                          human_melee_sound__repeatThreshold : float;
                          var human_melee_sound__repeatTime : float&;
                          @shared_comp human_voice_sound__path : Object;
                          @shared_comp human_melee_sound__irqs : Object;
                          sound_tags : Object;
                          var sound_event_group : SoundEventGroup&;
                          is_watched_sound : bool;
                          human_weap__gunEids : EidList const?;
                          human_weap__currentGunSlot : int const?;
                          transform : float3x4;
                          human_voice_effect__isActive = false;
                          human_speech__isSpeaking = false)
  if get_sync_time() < human_melee_sound__repeatTime + human_melee_sound__repeatThreshold
    return
  human_melee_sound__repeatTime = get_sync_time()

  if !is_watched_sound && !should_play(transform[3])
    return
  let gun = human_weap__gunEids != null && human_weap__currentGunSlot != null && *human_weap__currentGunSlot >= 0 ? (*human_weap__gunEids)[*human_weap__currentGunSlot] : INVALID_ENTITY_ID
  let meleeType : string = get_string(gun, "meleeSoundType", "hands")
  if empty(meleeType)
    return

  let irqObj = get_ecs_object(human_melee_sound__irqs, evt.irq)
  let weapon = (irqObj?.weapons ?as Object)?[meleeType] ?as Object
  if weapon == null
    return

/*
  // debug: tweak and debug sound delay
  human_melee_sound_delay_debug(250, weapon, sound_tags, is_watched_sound, human_voice_sound__path, sound_event_group, transform)
  return
*/

  if take_a_chance((*weapon).chance ?? 100)
    play_sound("", *weapon, sound_tags, float((*weapon).delay ?? 0) * 0.001, is_watched_sound, sound_event_group, transform)

  if take_a_chance((*weapon).voiceChance ?? 0)
    if !human_voice_effect__isActive && !human_speech__isSpeaking
      let voiceDelayMs = (*weapon).voiceDelay ?? 0
      let name = get_string(*weapon, "voiceName", "hands/whoosh")
      play_sound(name, human_voice_sound__path, sound_tags, float(voiceDelayMs) * 0.001, is_watched_sound, sound_event_group, transform)

  let secondary = (*weapon).secondary ?as Object
  if secondary != null
/*
    // debug: tweak and debug sound delay of SECONDARY
    human_melee_sound_delay_debug(500, secondary, sound_tags, is_watched_sound, human_voice_sound__path, sound_event_group, transform)
    return
*/
    if take_a_chance((*secondary).chance ?? 100)
      play_sound("", *secondary, sound_tags, float((*secondary).delay ?? 0) * 0.001, is_watched_sound, sound_event_group, transform)
