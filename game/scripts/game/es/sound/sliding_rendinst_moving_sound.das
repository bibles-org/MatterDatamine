require ecs
require soundEvent


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def sliding_rendinst_moving_sound_update(evt : Event;
                                         sliding_rendinst__slidedState : bool;
                                         transform : float3x4;

                                         sliding_rendinst_moving_sound__forwardPath : string;
                                         sliding_rendinst_moving_sound__backwardPath : string;

                                         var sliding_rendinst_moving_sound__slidedState : bool&;
                                         var sliding_rendinst_moving_sound__event : SoundEvent&)

  if !sliding_rendinst_moving_sound__event.enabled || sliding_rendinst_moving_sound__slidedState != sliding_rendinst__slidedState
    release(sliding_rendinst_moving_sound__event)
    sliding_rendinst_moving_sound__slidedState = sliding_rendinst__slidedState
    sliding_rendinst_moving_sound__event.enabled = true
    sliding_rendinst_moving_sound__event.abandonOnReset = true
    sliding_rendinst_moving_sound__event |> play(sliding_rendinst_moving_sound__slidedState ? sliding_rendinst_moving_sound__forwardPath : sliding_rendinst_moving_sound__backwardPath, transform[3])
  set_pos(sliding_rendinst_moving_sound__event, transform[3])

/*
// to release immediate without keyoff/fadeout when destroyed in progress
[es(tag=sound, on_disappear)]
def sliding_rendinst_moving_sound_disappear(evt : Event
                                            sliding_rendinst__progress : float
                                            var sliding_rendinst_moving_sound__event : SoundEvent&)
  sliding_rendinst_moving_sound__event.abandonOnReset = sliding_rendinst__progress <= 0. || sliding_rendinst__progress >= 1.
*/
