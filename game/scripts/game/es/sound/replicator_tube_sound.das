require ecs
require soundEvent
require sound_utils.modules.sound_player_common
require sound_utils.modules.sound_control_common
require game.es.client.replicator_containers_common
require DagorSystem


[es(tag=sound, on_appear, track=(sound_control__state, replicator_tube__status))]
def replicator_tube_sound_track(evt : Event;
                                replicator_tube__status : int;
                                var replicator_tube_sound__prevStatus : int&;
                                var replicator_tube_sound__event : SoundEvent&;
                                replicator_tube_sound__workingPath : string;
                                replicator_tube_sound__beginPath : string;
                                replicator_tube_sound__endPath : string;
                                sound_control__state : int;
                                var managed_sound__excluded : bool&;
                                transform : float3x4)

  release(replicator_tube_sound__event)

  managed_sound__excluded = replicator_tube__status != int(TubeWorkStatus.REPLICATOR_IN_PROGRESS)

  if have_sound(sound_control__state)
    if replicator_tube__status == int(TubeWorkStatus.REPLICATOR_IN_PROGRESS)
      replicator_tube_sound__event |> play(replicator_tube_sound__workingPath, transform[3])

  assert(int(TubeWorkStatus.REPLICATOR_EMPTY) >= 0)
  if replicator_tube_sound__prevStatus != replicator_tube__status && replicator_tube_sound__prevStatus >= int(TubeWorkStatus.REPLICATOR_EMPTY)
    if replicator_tube__status == int(TubeWorkStatus.REPLICATOR_RESETING)
      oneshot(replicator_tube_sound__beginPath, transform[3])
    if replicator_tube__status == int(TubeWorkStatus.REPLICATOR_DONE)
      oneshot(replicator_tube_sound__endPath, transform[3])
  replicator_tube_sound__prevStatus = replicator_tube__status
