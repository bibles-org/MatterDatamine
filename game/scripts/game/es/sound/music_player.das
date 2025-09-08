require ecs
require soundEvent
require soundSystem
require game.events.music_player_events


def stop(var music_player__trackLength : int&;
         var music_player__pos : int&;
         var music_player__event : SoundEvent&;
         var music_player__isPlaying : bool&)
  music_player__trackLength = 0
  music_player__pos = 0
  music_player__event |> release()
  music_player__isPlaying = false


def play(new_track : string;
         pos : int;
         music_player__volume : float;
         var music_player__track : das_string&;
         var music_player__trackLength : int&;
         var music_player__pos : int&;
         var music_player__event : SoundEvent&;
         var music_player__isPlaying : bool&)

  music_player__event |> play(new_track, get_listener_pos())
  music_player__isPlaying = is_playing(music_player__event)
  if !music_player__isPlaying
    stop(music_player__trackLength,
         music_player__pos,
         music_player__event,
         music_player__isPlaying)
    return

  music_player__track := new_track
  music_player__trackLength = get_length(new_track)
  music_player__pos = clamp(pos, 0, music_player__trackLength)
  set_timeline_position(music_player__event, music_player__pos)
  set_volume(music_player__event, music_player__volume)


[es(tag=sound)]
def music_player_stop(evt : CmdMusicPlayerStop;
                      var music_player__trackLength : int&;
                      var music_player__pos : int&;
                      var music_player__event : SoundEvent&;
                      var music_player__isPlaying : bool&)
  stop(music_player__trackLength,
       music_player__pos,
       music_player__event,
       music_player__isPlaying)


[es(tag=sound)]
def music_player_play(evt : CmdMusicPlayerPlay;
                      var music_player__track : das_string&;
                      music_player__volume : float;
                      var music_player__trackLength : int&;
                      var music_player__pos : int&;
                      var music_player__event : SoundEvent&;
                      var music_player__isPlaying : bool&)
  play(evt.track,
       evt.pos,
       music_player__volume,
       music_player__track,
       music_player__trackLength,
       music_player__pos,
       music_player__event,
       music_player__isPlaying)


[es(tag=sound, track=music_player__volume)]
def music_player_set_volume(evt : Event;
                            music_player__volume : float;
                            music_player__event : SoundEvent&)
  set_volume(music_player__event, music_player__volume)


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def music_player_update(evt : Event;
                        var music_player__pos : int&;
                        var music_player__isPlaying : bool&;
                        music_player__event : SoundEvent&)

  music_player__isPlaying = is_playing(music_player__event)
  if music_player__isPlaying
    music_player__pos = get_timeline_position(music_player__event)
    set_pos(music_player__event, get_listener_pos())


[es(tag=sound, on_appear, track=sound_banks_state__isPresetLoaded)]
def music_player_preset_loaded(evt : Event;
                               sound_banks_state__isPresetLoaded : bool;
                               var music_player__readyToPlay : bool&)
  music_player__readyToPlay = sound_banks_state__isPresetLoaded
