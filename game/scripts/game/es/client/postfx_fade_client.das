require ecs
require app
require math.color
require game.events.events
require game.es.client.postfx_fade_common
require game.es.system_common
require player
require DagorMath
require DagorSystem


[es(tag=gameClient, no_order)]
def postfx_fade_layer_tweening(act : UpdateStageInfoAct;
                               eid : EntityId;
                               var postfx_fade_layer_tweening__destroyed : bool&;
                               postfx_fade_layer_tweening__layerNameHash : int;
                               postfx_fade_layer_tweening__startAt : float;
                               postfx_fade_layer_tweening__finishAt : float;
                               postfx_fade_layer_tweening__colorFrom : float4;
                               postfx_fade_layer_tweening__colorTo : float4)
  assume layerNameHash = postfx_fade_layer_tweening__layerNameHash
  assume startAt = postfx_fade_layer_tweening__startAt
  assume finishAt = postfx_fade_layer_tweening__finishAt
  assume colorFrom = postfx_fade_layer_tweening__colorFrom
  assume colorTo = postfx_fade_layer_tweening__colorTo

  if act.curTime >= postfx_fade_layer_tweening__finishAt
    postfx_fade_print_log("postfx_fade_layer_tweening finished [{layerNameHash}] color={postfx_fade_layer_tweening__colorTo}")
    if colorTo.w == 0.0 && layerNameHash != POSTFX_FADE_DEFAULT_LAYER
      postfx_fade_remove_color_layer(postfx_fade_layer_tweening__layerNameHash)
    else
      postfx_fade_ensure_color_layer(postfx_fade_layer_tweening__layerNameHash) <| $(var color_layer : float4&)
        color_layer = colorTo
    broadcastEvent(EventPostFxFadeFinished(layerNameHash = layerNameHash, color = colorTo))
    postfx_fade_layer_tweening__destroyed = true
    destroyEntity(eid)
  else
    let progress = cvt(act.curTime, startAt, finishAt, 0.0, 1.0)
    postfx_fade_ensure_color_layer(postfx_fade_layer_tweening__layerNameHash) <| $(var color_layer : float4&)
      color_layer = lerp(colorFrom, colorTo, progress)


def is_actor_postfx_fade_affected(actor_eid : EntityId; only_local : bool)
  var result = false
  query(actor_eid) <| $ [es] (watchedByPlr : EntityId const?;
                              hero : Tag const?;
                              createdByPlr : EntityId const?)
    result = only_local ? (hero != null) : (watchedByPlr != null)
    if !result && createdByPlr != null
      result = (*createdByPlr == get_local_player_eid())

  return result


[es(tag=gameClient, on_appear)]
def postfx_fade_affect_init(evt : Event;
                            postfx_fade_affect__layerName : string;
                            var postfx_fade_affect__layerNameHash : int&)
  postfx_fade_affect__layerNameHash = int(ecs_hash(postfx_fade_affect__layerName))


[es(tag=gameClient, on_appear, after=postfx_fade_affect_init)]
def postfx_fade_affect_in(evt : Event;
                          postfx_fade_affect__fadeInTime : float;
                          postfx_fade_affect__fadeColor : E3DCOLOR;
                          postfx_fade_affect__affectOnlyLocal : bool = false;
                          postfx_fade_affect__layerNameHash : int;
                          game_effect__attachedTo : EntityId)
  if is_actor_postfx_fade_affected(game_effect__attachedTo, postfx_fade_affect__affectOnlyLocal)
    postfx_fadein(float4(Color4(postfx_fade_affect__fadeColor)), postfx_fade_affect__fadeInTime, postfx_fade_affect__layerNameHash)


[es(tag=gameClient, on_disappear)]
def postfx_fade_affect_out(evt : Event;
                           postfx_fade_affect__fadeOutTime : float;
                           postfx_fade_affect__affectOnlyLocal : bool = false;
                           postfx_fade_affect__layerNameHash : int;
                           onboarding_effect_guaranteed_destroy : Tag const?;
                           game_effect__attachedTo : EntityId)
  if onboarding_effect_guaranteed_destroy != null || is_actor_postfx_fade_affected(game_effect__attachedTo, postfx_fade_affect__affectOnlyLocal)
    postfx_fadeout(postfx_fade_affect__fadeOutTime, postfx_fade_affect__layerNameHash)


[es(tag=gameClient, on_appear, after=postfx_fade_affect_init)]
def postfx_fadein_affect_appear(evt : Event;
                                postfx_fadein_affect__time : float;
                                postfx_fadein_affect__color : E3DCOLOR;
                                postfx_fade_affect__affectOnlyLocal : bool = false;
                                postfx_fade_affect__layerNameHash : int;
                                game_effect__attachedTo : EntityId)
  if is_actor_postfx_fade_affected(game_effect__attachedTo, postfx_fade_affect__affectOnlyLocal)
    postfx_fadein(float4(Color4(postfx_fadein_affect__color)), postfx_fadein_affect__time, postfx_fade_affect__layerNameHash)


[es(tag=gameClient, on_appear, after=postfx_fade_affect_init)]
def postfx_fadeout_affect_appear(evt : Event;
                                 postfx_fadeout_affect__time : float;
                                 postfx_fade_affect__affectOnlyLocal : bool = false;
                                 postfx_fade_affect__layerNameHash : int;
                                 game_effect__attachedTo : EntityId)
  if is_actor_postfx_fade_affected(game_effect__attachedTo, postfx_fade_affect__affectOnlyLocal)
    postfx_fadeout(postfx_fadeout_affect__time, postfx_fade_affect__layerNameHash)


[es(tag=gameClient, on_appear, after=postfx_fade_affect_init)]
def postfx_fade_immediate_affect(evt : Event;
                                 postfx_fade_immediate__color : E3DCOLOR;
                                 postfx_fade_affect__affectOnlyLocal : bool = false;
                                 postfx_fade_affect__layerNameHash : int;
                                 game_effect__attachedTo : EntityId)
  if is_actor_postfx_fade_affected(game_effect__attachedTo, postfx_fade_affect__affectOnlyLocal)
    assume color = float4(Color4(postfx_fade_immediate__color))
    postfx_fade_immediate(color, postfx_fade_affect__layerNameHash)


[es(tag=gameClient, on_appear, after=postfx_fade_affect_init)]
def postfx_fade_immediate_out_affect(evt : Event;
                                     postfx_fade_immediate_out_time : float;
                                     postfx_fade_immediate_out__color : E3DCOLOR;
                                     postfx_fade_affect__affectOnlyLocal : bool = false;
                                     postfx_fade_affect__layerNameHash : int;
                                     game_effect__attachedTo : EntityId)
  if is_actor_postfx_fade_affected(game_effect__attachedTo, postfx_fade_affect__affectOnlyLocal)
    assume color = float4(Color4(postfx_fade_immediate_out__color))
    postfx_fade_start(color,
                      float4(color.x, color.y, color.z, 0.0),
                      postfx_fade_immediate_out_time,
                      postfx_fade_affect__layerNameHash)
