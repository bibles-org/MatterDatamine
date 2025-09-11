require ecs
require ecs.safe
require ecs.common
require app // get_sync_time
require soundHash
require soundEvent
require soundSystem
require sound_utils.modules.sound_player_common
require sound_utils.modules.sound_control_common
require human_sounds.modules.human_voice_effect_common
require human_sounds.modules.human_sounds_events
require human_sounds_net.modules.human_sounds_net_events

require strings
require DagorSystem


[es(tag=sound, track=is_watched_sound)]
def human_voice_effect_on_watched(evt : Event;
                                  sound_control__state : int = default_sound_control_state();
                                  human_voice_effect__type : string;
                                  is_watched_sound = false;
                                  @shared_comp human_voice_sound__path : Object;
                                  @shared_comp human_voice_sound__descs : Object;
                                  var human_voice_effect__event : SoundEvent&;
                                  sound_tags : Object;
                                  transform : float3x4)
  if have_sound(sound_control__state) && is_playing(human_voice_effect__event) && !is_oneshot(human_voice_effect__event)
    release(human_voice_effect__event)
    human_voice_effect__event |> reset(play(human_voice_effect__type, human_voice_sound__path, human_voice_sound__descs, sound_tags, is_watched_sound, transform[3], false))


def abandon_or_release(var human_voice_effect__event : SoundEvent&; _abandon : bool)
  if _abandon
    abandon(human_voice_effect__event)
  else
    release(human_voice_effect__event)


[es(tag=sound, on_appear, track=(human_voice_effect__activeEffects, sound_control__state))]
def human_voice_effect_on_change(evt : Event;
                                 var human_voice_effect__type : das_string&;
                                 var human_voice_effect__isInited : bool&;
                                 var human_voice_effect__event : SoundEvent&;
                                 var human_voice_effect__isActive : bool&;
                                 human_voice_effect__activeEffects : Object;

                                 @shared_comp human_voice_effect__allOrderedEffects : StringList;
                                 @shared_comp human_voice_sound__path : Object;
                                 @shared_comp human_voice_sound__descs : Object;

                                 sound_control__state : int = default_sound_control_state();
                                 is_watched_sound = false;

                                 sound_tags : Object;
                                 transform : float3x4)

  let newId = get_top_active_effect(human_voice_effect__activeEffects, human_voice_effect__allOrderedEffects)
  let curId = string(human_voice_effect__type)

  if !have_sound(sound_control__state)
    human_voice_effect__isInited = false
    human_voice_effect__type := newId
    human_voice_effect__isActive = !empty(human_voice_effect__type)
    if is_valid_handle_value(human_voice_effect__event)
      release(human_voice_effect__event)
    return

  if !human_voice_effect__isInited || newId != curId
    human_voice_effect__type := newId

    if is_valid_handle_value(human_voice_effect__event)
      if !keyoff(human_voice_effect__event)
        abandon_or_release(human_voice_effect__event, empty(newId))

    let curDesc = human_voice_sound__descs[curId] ?as Object
    let newDesc = human_voice_sound__descs[newId] ?as Object

    if !empty(newId)
      let newStartDesc = newDesc?.start ?as Object
      if newStartDesc != null
        // start ----
        if human_voice_effect__isInited
          abandon_or_release(human_voice_effect__event, newDesc?.abandoner != null)
          human_voice_effect__event |> reset(play_desc(*newStartDesc, human_voice_sound__path, sound_tags, is_watched_sound, transform[3], false))
      else
        abandon_or_release(human_voice_effect__event, newDesc?.abandoner != null)
        if newDesc != null
          // loop ----
          human_voice_effect__event |> reset(play_desc(*newDesc, human_voice_sound__path, sound_tags, is_watched_sound, transform[3], false))

    elif human_voice_effect__isInited
      // ---- end
      let curEndDesc = curDesc?.end ?as Object
      if curEndDesc != null
        abandon_or_release(human_voice_effect__event, newDesc?.abandoner != null)
        human_voice_effect__event |> reset(play_desc(*curEndDesc, human_voice_sound__path, sound_tags, is_watched_sound, transform[3], false))

    if human_voice_effect__isInited
      // parallel oneshots
      let curToNew = newDesc?[curId] ?as Object
      if curToNew != null
        play_desc(*curToNew, human_voice_sound__path, sound_tags, is_watched_sound, transform[3])

    human_voice_effect__isInited = true

  human_voice_effect__isActive = !empty(human_voice_effect__type) || is_valid_handle_value(human_voice_effect__event)


[es(tag=sound)]
def human_voice_effect_on_net_cmd(evt : CmdNetHumanVoiceEffect;
                                  sound_control__state : int = default_sound_control_state();
                                  var human_voice_effect__event : SoundEvent&;
                                  @shared_comp human_voice_sound__path : Object;
                                  @shared_comp human_voice_sound__descs : Object;
                                  human_voice_effect__isActive : bool;
                                  human_speech__isSpeaking : bool = false;
                                  is_watched_sound : bool = false;
                                  sound_tags : Object;
                                  transform : float3x4)
  let maxDelay = 3.
  if have_sound(sound_control__state) && !human_voice_effect__isActive && !human_speech__isSpeaking && get_sync_time() < evt.time + maxDelay
    release(human_voice_effect__event)
    human_voice_effect__event |> reset(play(evt.phrase, human_voice_sound__path, human_voice_sound__descs, sound_tags, is_watched_sound, transform[3], false))


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def human_voice_effect_update(evt : Event;
                              transform : float3x4;
                              var human_voice_effect__event : SoundEvent&;
                              var human_voice_effect__isActive : bool&;
                              human_voice_effect__type : string)
  if is_valid_handle_value(human_voice_effect__event)
    if is_playing(human_voice_effect__event)
      set_pos(human_voice_effect__event, transform[3])
      human_voice_effect__isActive = true
      return
    release(human_voice_effect__event)
  human_voice_effect__isActive = !empty(human_voice_effect__type)


[es(tag=sound)]
def human_voice_effect_oneshot(evt : CmdHumanVoiceEffectOneshot;

                               sound_control__state : int = default_sound_control_state();

                               @shared_comp human_voice_sound__path : Object;
                               @shared_comp human_voice_sound__descs : Object;
                               human_voice_effect__isActive : bool;
                               human_voice_effect__type : string;
                               human_speech__isSpeaking : bool = false;
                               is_watched_sound : bool = false;
                               sound_tags : Object;
                               transform : float3x4;
                               var sound_event_group : SoundEventGroup?)

  if !human_speech__isSpeaking && (have_sound(sound_control__state) || evt.ignoreDisabledSoundControl) && is_hearable_sound_state(sound_control__state) && sound_banks_is_master_preset_loaded()

    if human_voice_effect__isActive && !empty(human_voice_effect__type)
      let desc = get_desc(human_voice_sound__descs, evt.phrase)
      if desc == null || get_desc(*desc, human_voice_effect__type) == null
        return

    var handle = invalid_sound_event_handle()
    if sound_event_group != null // put to group to release on recreation to dead_soldier_sound
      handle = play(evt.phrase, human_voice_sound__path, human_voice_sound__descs, sound_tags, is_watched_sound, transform[3], sound_hash("voiceEffect"), *sound_event_group)
    else
      handle = play(evt.phrase, human_voice_sound__path, human_voice_sound__descs, sound_tags, is_watched_sound, transform[3])
    if !empty(evt.varName)
      set_var(handle, evt.varName, evt.varValue)
