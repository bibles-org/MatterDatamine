require ecs
require soundEvent
require sound_utils.modules.sound_player_common
require danetlibs.renderer.includes.pufd_events
require DngHuman


[es(tag=sound)]
def monstrified_changed_human_idle_sound(info : ParallelUpdateFrameDelayed&;
                                         @shared_comp monstrified_changed_human_idle_sound__path : Object;
                                         var monstrified_changed_human_idle_sound__lastTime : float&;
                                         var monstrified_changed_human_idle_sound__event : SoundEvent&;

                                         monstrified_changed_human_idle_sound__idleInterval : float;
                                         monstrified_changed_human_idle_sound__runInterval : float;
                                         monstrified_changed_human_idle_sound__sprintInterval : float;
                                         var monstrified_changed_human_idle_sound__interval : float&;
                                         monstrified_changed_human_idle_sound__intervalChangeSpeed : float;

                                         is_watched_sound : bool;
                                         sound_tags : Object;
                                         transform : float3x4;
                                         human_net_phys : HumanActor)

  assume moveState = human_net_phys.phys.currentState.moveState
  assume sprintInterval = monstrified_changed_human_idle_sound__sprintInterval
  assume runInterval = monstrified_changed_human_idle_sound__runInterval
  assume idleInterval = monstrified_changed_human_idle_sound__idleInterval

  let interval = moveState == HUMoveState.EMS_SPRINT ? sprintInterval : moveState == HUMoveState.EMS_RUN ? runInterval : idleInterval

  monstrified_changed_human_idle_sound__interval += (interval - monstrified_changed_human_idle_sound__interval) * saturate(info.dt * monstrified_changed_human_idle_sound__intervalChangeSpeed)

  if info.curTime >= monstrified_changed_human_idle_sound__lastTime + monstrified_changed_human_idle_sound__interval
    monstrified_changed_human_idle_sound__lastTime = info.curTime
    monstrified_changed_human_idle_sound__event.enabled = true
    monstrified_changed_human_idle_sound__event |> reset(play_path(monstrified_changed_human_idle_sound__path, sound_tags, is_watched_sound, transform[3], false))

  if monstrified_changed_human_idle_sound__event.enabled
    if is_playing(monstrified_changed_human_idle_sound__event)
      set_pos(monstrified_changed_human_idle_sound__event, transform[3])
    else
      monstrified_changed_human_idle_sound__event.enabled = false
