require ecs
require DagorInput
require game.events.input_events
require game.events.events_active_matter


def initActions(var replay_track_input__saveKeyFrame : int&;
                var replay_track_input__deleteCurrentKeyFrame : int&;
                var replay_track_input__clearAllKeyFrames : int&;
                var replay_track_input__loadKeyFrames : int&;
                var replay_track_input__toggleInterp : int&;
                var replay_track_input__playRotation : int&;
                var replay_track_input__playPosition : int&;
                var replay_track_input__playRoll : int&;
                var replay_track_input__playFov : int&)
  replay_track_input__saveKeyFrame = int(get_action_handle("ReplayTrack.SaveKeyFrame", TYPEGRP_DIGITAL))
  replay_track_input__deleteCurrentKeyFrame = int(get_action_handle("ReplayTrack.DeleteCurrentKeyFrame", TYPEGRP_DIGITAL))
  replay_track_input__clearAllKeyFrames = int(get_action_handle("ReplayTrack.ClearAllKeyFrames", TYPEGRP_DIGITAL))
  replay_track_input__loadKeyFrames = int(get_action_handle("ReplayTrack.LoadKeyFrames", TYPEGRP_DIGITAL))
  replay_track_input__toggleInterp = int(get_action_handle("ReplayTrack.ToggleInterpolation", TYPEGRP_DIGITAL))
  replay_track_input__playRotation = int(get_action_handle("ReplayTrack.TogglePlayRotation", TYPEGRP_DIGITAL))
  replay_track_input__playPosition = int(get_action_handle("ReplayTrack.TogglePlayPosition", TYPEGRP_DIGITAL))
  replay_track_input__playRoll = int(get_action_handle("ReplayTrack.TogglePlayRoll", TYPEGRP_DIGITAL))
  replay_track_input__playFov = int(get_action_handle("ReplayTrack.TogglePlayFov", TYPEGRP_DIGITAL))


def resetActions(var replay_track_input__saveKeyFrame : int&;
                 var replay_track_input__deleteCurrentKeyFrame : int&;
                 var replay_track_input__clearAllKeyFrames : int&;
                 var replay_track_input__loadKeyFrames : int&;
                 var replay_track_input__toggleInterp : int&;
                 var replay_track_input__playRotation : int&;
                 var replay_track_input__playPosition : int&;
                 var replay_track_input__playRoll : int&;
                 var replay_track_input__playFov : int&)
  replay_track_input__saveKeyFrame = int(BAD_ACTION_HANDLE)
  replay_track_input__deleteCurrentKeyFrame = int(BAD_ACTION_HANDLE)
  replay_track_input__clearAllKeyFrames = int(BAD_ACTION_HANDLE)
  replay_track_input__loadKeyFrames = int(BAD_ACTION_HANDLE)
  replay_track_input__toggleInterp = int(BAD_ACTION_HANDLE)
  replay_track_input__playRotation = int(BAD_ACTION_HANDLE)
  replay_track_input__playPosition = int(BAD_ACTION_HANDLE)
  replay_track_input__playRoll = int(BAD_ACTION_HANDLE)
  replay_track_input__playFov = int(BAD_ACTION_HANDLE)


[es(tag=(playingReplay, input))]
def replay_track_input_setup(evt : EventDaInputInit;
                             var replay_track_input__saveKeyFrame : int&;
                             var replay_track_input__deleteCurrentKeyFrame : int&;
                             var replay_track_input__clearAllKeyFrames : int&;
                             var replay_track_input__loadKeyFrames : int&;
                             var replay_track_input__toggleInterp : int&;
                             var replay_track_input__playRotation : int&;
                             var replay_track_input__playPosition : int&;
                             var replay_track_input__playRoll : int&;
                             var replay_track_input__playFov : int&)
  if evt.init
    initActions(replay_track_input__saveKeyFrame, replay_track_input__deleteCurrentKeyFrame, replay_track_input__clearAllKeyFrames,
      replay_track_input__loadKeyFrames, replay_track_input__toggleInterp, replay_track_input__playRotation,
      replay_track_input__playPosition, replay_track_input__playRoll, replay_track_input__playFov)
  else
    resetActions(replay_track_input__saveKeyFrame, replay_track_input__deleteCurrentKeyFrame, replay_track_input__clearAllKeyFrames,
      replay_track_input__loadKeyFrames, replay_track_input__toggleInterp, replay_track_input__playRotation,
      replay_track_input__playPosition, replay_track_input__playRoll, replay_track_input__playFov)


[es(tag=(playingReplay, input), on_appear)]
def replay_track_input_appear(evt : Event;
                              var replay_track_input__saveKeyFrame : int&;
                              var replay_track_input__deleteCurrentKeyFrame : int&;
                              var replay_track_input__clearAllKeyFrames : int&;
                              var replay_track_input__loadKeyFrames : int&;
                              var replay_track_input__toggleInterp : int&;
                              var replay_track_input__playRotation : int&;
                              var replay_track_input__playPosition : int&;
                              var replay_track_input__playRoll : int&;
                              var replay_track_input__playFov : int&)
  initActions(replay_track_input__saveKeyFrame, replay_track_input__deleteCurrentKeyFrame, replay_track_input__clearAllKeyFrames,
    replay_track_input__loadKeyFrames, replay_track_input__toggleInterp, replay_track_input__playRotation,
    replay_track_input__playPosition, replay_track_input__playRoll, replay_track_input__playFov)


[es(tag=(playingReplay, input), on_disappear)]
def replay_track_input_dissapear(evt : Event;
                                 var replay_track_input__saveKeyFrame : int&;
                                 var replay_track_input__deleteCurrentKeyFrame : int&;
                                 var replay_track_input__clearAllKeyFrames : int&;
                                 var replay_track_input__loadKeyFrames : int&;
                                 var replay_track_input__toggleInterp : int&;
                                 var replay_track_input__playRotation : int&;
                                 var replay_track_input__playPosition : int&;
                                 var replay_track_input__playRoll : int&;
                                 var replay_track_input__playFov : int&)
  resetActions(replay_track_input__saveKeyFrame, replay_track_input__deleteCurrentKeyFrame, replay_track_input__clearAllKeyFrames,
    replay_track_input__loadKeyFrames, replay_track_input__toggleInterp, replay_track_input__playRotation,
    replay_track_input__playPosition, replay_track_input__playRoll, replay_track_input__playFov)


[es(tag=(playingReplay, input))]
def replay_track_input_action_triggered(evt : EventDaInputActionTriggered;
                                        replay_track_input__saveKeyFrame : int;
                                        replay_track_input__deleteCurrentKeyFrame : int;
                                        replay_track_input__clearAllKeyFrames : int;
                                        replay_track_input__loadKeyFrames : int;
                                        replay_track_input__toggleInterp : int;
                                        replay_track_input__playRotation : int;
                                        replay_track_input__playPosition : int;
                                        replay_track_input__playRoll : int;
                                        replay_track_input__playFov : int)
  find_query() <| $ [es(REQUIRE=replay_track)] (eid : EntityId;
                                                replay_track__currentKeyFrame : int)
    if int(evt.action) == replay_track_input__saveKeyFrame
      sendEvent(eid, ReplayTrackSaveKeyFrame())
    elif int(evt.action) == replay_track_input__deleteCurrentKeyFrame
      sendEvent(eid, ReplayTrackDeleteKeyFrame(index = replay_track__currentKeyFrame))
    elif int(evt.action) == replay_track_input__clearAllKeyFrames
      sendEvent(eid, ReplayTrackClearAllKeyFrames())
    elif int(evt.action) == replay_track_input__loadKeyFrames
      sendEvent(eid, ReplayTrackDeserialize(switchCamera = true))
    elif int(evt.action) == replay_track_input__toggleInterp
      sendEvent(eid, ReplayTrackToggleInterp())
    elif int(evt.action) == replay_track_input__playRotation
      sendEvent(eid, ReplayTrackTogglePlayRotation())
    elif int(evt.action) == replay_track_input__playPosition
      sendEvent(eid, ReplayTrackTogglePlayPosition())
    elif int(evt.action) == replay_track_input__playRoll
      sendEvent(eid, ReplayTrackTogglePlayRoll())
    elif int(evt.action) == replay_track_input__playFov
      sendEvent(eid, ReplayTrackTogglePlayFov())
    return true
