require ecs
require ecs.safe
require app
require game.es.endgame_enums_common
require game.events.events_active_matter
require game.es.client.postfx_fade_common
require game.events.events_game
require DagorMath
require DagorSystem


def is_hero_dead()
  var dead = false
  query() <| $ [es(REQUIRE=hero)] (isAlive : bool = true)
    dead = !isAlive
  return dead


[es(tag=gameClient, track=endgame_controller__state)]
def endgame_controller_track_state(evt : Event;
                                   endgame_controller__state : int;
                                   endgame_controller__deathFadeInTime : float;
                                   endgame_controller__fadeInTime : float;
                                   endgame_controller__fadeInColor : E3DCOLOR;
                                   endgame_controller__fadeOutTime : float;
                                   endgame_controller__deathFadeDelay : float;
                                   endgame_controller__debriefing__showDelay : float;
                                   var endgame_controller__nextStateAt : float&)
  print("[ENDGAME] endgame_controller_track_state: state={endgame_controller__state}")

  endgame_controller__nextStateAt = -1.0

  if endgame_controller__state == int(EndgameControllerState.NONE)
    postfx_fadeout(endgame_controller__fadeOutTime, POSTFX_FADE_DEFAULT_LAYER)
    postfx_fadeout(endgame_controller__fadeOutTime, get_endgame_postfx_fade_layer_hash())
  elif endgame_controller__state == int(EndgameControllerState.FADE_DELAY)
    if is_hero_dead()
      endgame_controller__nextStateAt = get_sync_time() + endgame_controller__deathFadeDelay
    else
      endgame_controller__nextStateAt = get_sync_time()
  elif endgame_controller__state == int(EndgameControllerState.FADEIN)
    var fadeTime = endgame_controller__fadeInTime
    if is_hero_dead()
      fadeTime = endgame_controller__deathFadeInTime

    postfx_fadein(float4(Color4(endgame_controller__fadeInColor)), fadeTime, get_endgame_postfx_fade_layer_hash())
    endgame_controller__nextStateAt = get_sync_time() + fadeTime + endgame_controller__debriefing__showDelay
  elif endgame_controller__state == int(EndgameControllerState.SPECTATING)
    postfx_fadeout(endgame_controller__fadeOutTime, POSTFX_FADE_DEFAULT_LAYER)
    postfx_fadeout(endgame_controller__fadeOutTime, get_endgame_postfx_fade_layer_hash())


[es(tag=gameClient, on_disappear)]
def endgame_controller_disappear(evt : Event;
                                 endgame_controller__fadeOutTime : float)
  // Ensure layer fadeout for sure
  postfx_fadeout(endgame_controller__fadeOutTime, get_endgame_postfx_fade_layer_hash())


[es(tag=gameClient, no_order)]
def endgame_controller_update(act : ParallelUpdateFrameDelayed;
                              var endgame_controller__nextStateAt : float&;
                              var endgame_controller__state : int&)
  if endgame_controller__nextStateAt <= 0.0 || act.curTime < endgame_controller__nextStateAt
    if endgame_controller__state == int(EndgameControllerState.DEBRIEFING)
      find_query() <| $ [es(REQUIRE=player)] (activeCamEid : EntityId;
                                              is_local : bool)
        if !is_local
          return false

        query(activeCamEid) <| $ [es] (camera__target : EntityId;
                                       var transform aka camera_transform : float3x4)
          var cameraTargetValid = false
          query(camera__target) <| $ [es] (isAlive : bool = false)
            cameraTargetValid = isAlive

          if !cameraTargetValid
            // Hide camera in the sky
            camera_transform[0] = float3(0.0, 0.0, 1.0)
            camera_transform[1] = float3(1.0, 0.0, 0.0)
            camera_transform[2] = float3(0.0, 1.0, 0.0)
            camera_transform[3].y = 1e3

        return true

    return

  endgame_controller__nextStateAt = -1.0

  if endgame_controller__state == int(EndgameControllerState.FADE_DELAY)
    let postfxLayerNameHash = get_endgame_postfx_fade_layer_hash()
    if is_postfx_fadein_in_progress(postfxLayerNameHash) || get_postfx_fade_progress(postfxLayerNameHash) >= 1.0 - 1e-3
      endgame_controller__state = int(EndgameControllerState.DEBRIEFING)
    else
      endgame_controller__state = int(EndgameControllerState.FADEIN)
  elif endgame_controller__state == int(EndgameControllerState.FADEIN)
    endgame_controller__state = int(EndgameControllerState.DEBRIEFING)
  else
    logerr("[ENDGAME] endgame_controller_update: unexpected controller state - {endgame_controller__state}")


[es(tag=gameClient, REQUIRE=player)]
def endgame_controller_on_debriefing(evt : EventEndgamePlayerResult;
                                     is_local : bool)
  if !is_local
    return

  find_query() <| $ [es] (var endgame_controller__state : int&;
                          var endgame_controller__debriefing__reason : int&;
                          var endgame_controller__debriefing__team : int&;
                          var endgame_controller__debriefing__autoExit : bool&;
                          var endgame_controller__debriefing__allowSpectate : bool&)
    endgame_controller__state = int(EndgameControllerState.FADE_DELAY)
    endgame_controller__debriefing__reason = evt.reason
    endgame_controller__debriefing__team = evt.team
    endgame_controller__debriefing__allowSpectate = evt.allowSpectate
    endgame_controller__debriefing__autoExit = evt.autoExit
    return true


[es(tag=gameClient, on_appear, REQUIRE=hero)]
def endgame_controller_possess_hero(evt : Event)
  find_query() <| $ [es(REQUIRE_NOT=endgame_controller_ignore_possess)] (endgame_controller__fadeOutTime : float;
                                                                         var endgame_controller__state : int&)
    // Revive
    if endgame_controller__state == int(EndgameControllerState.DEBRIEFING) || endgame_controller__state == int(EndgameControllerState.SPECTATING)
      postfx_fadeout(endgame_controller__fadeOutTime, get_endgame_postfx_fade_layer_hash())
      endgame_controller__state = int(EndgameControllerState.NONE)
    return true


[es(tag=gameClient)]
def endgame_controller_reset_on_round_change(evt : EventNexusRoundModeRoundChange;
                                             var endgame_controller__state : int&)
  if endgame_controller__state == int(EndgameControllerState.DEBRIEFING) || endgame_controller__state == int(EndgameControllerState.SPECTATING)
    endgame_controller__state = int(EndgameControllerState.NONE)


[es(tag=gameClient, REQUIRE=player)]
def endgame_controller_spectate_request(evt : CmdDebriefingSpectateRequest;
                                        is_local : bool)
  if !is_local
    return

  find_query() <| $ [es] (var endgame_controller__state : int&)
    if endgame_controller__state == int(EndgameControllerState.DEBRIEFING)
      endgame_controller__state = int(EndgameControllerState.SPECTATING)
    return true


[es(tag=gameClient, REQUIRE=player)]
def endgame_controller_open_debriefing_request(evt : CmdOpenDebriefingRequest;
                                               is_local : bool)
  if !is_local
    return

  find_query() <| $ [es] (var endgame_controller__state : int&)
    if endgame_controller__state == int(EndgameControllerState.SPECTATING)
      endgame_controller__state = int(EndgameControllerState.DEBRIEFING)
    return true