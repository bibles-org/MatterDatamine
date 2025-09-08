require ecs
require math.base
require game.events.events_active_matter


[es(on_appear)]
def portal_appear(evt : Event;
                  portal__scales : float2;
                  portal__openCloseTime : float2 const?;
                  var transform : float3x4&;
                  var portal__wishScale, portal__curScale, portal__scalingSpd : float&;
                  var portal__lastScale : float?)
  if portal__lastScale != null
    *portal__lastScale = portal__curScale
  if portal__openCloseTime != null
    portal__wishScale = portal__scales.y
    portal__curScale = portal__scales.x
    portal__scalingSpd = (portal__scales.y - portal__scales.x) / (*portal__openCloseTime).x
  else
    portal__wishScale = portal__scales.x
    portal__curScale = portal__scales.x
  var tm = scale_tm(portal__curScale)
  tm[3] = transform[3]
  transform = tm


[es(no_order)]
def portal_scaling(act : ParallelUpdateFrameDelayed;
                   portal__wishScale, portal__scalingSpd : float;
                   var transform : float3x4&;
                   var portal__curScale : float&;
                   var portal__lastScale : float?)
  if !is_equal_float(portal__curScale, portal__wishScale)
    if portal__lastScale != null
      *portal__lastScale = portal__curScale
    portal__curScale = move_to_scalar(portal__curScale, portal__wishScale, act.dt, portal__scalingSpd)
    var tm = scale_tm(portal__curScale)
    tm[3] = transform[3]
    transform = tm


[es(after=portal_scaling)]
def portal_scaling_reverse(act : ParallelUpdateFrameDelayed;
                           portal__scales, portal__openCloseTime : float2;
                           portal__curScale : float;
                           var portal__scalingSpd, portal__wishScale : float&)
  if is_equal_float(portal__curScale, portal__wishScale) && !is_equal_float(portal__wishScale, portal__scales.x)
    portal__wishScale = portal__scales.x
    portal__scalingSpd = (portal__scales.y - portal__scales.x) / portal__openCloseTime.y


[es(tag=server, after=portal_scaling_reverse, REQUIRE=portal__openCloseTime)]
def portal_scaling_reverse_server(act : ParallelUpdateFrameDelayed;
                                  eid : EntityId;
                                  portal__scales : float2;
                                  portal__curScale : float;
                                  portal__wishScale : float)
  if is_equal_float(portal__curScale, portal__wishScale) && is_equal_float(portal__wishScale, portal__scales.x)
    destroyEntity(eid)


[es(tag=gameClient, after=portal_scaling_reverse, REQUIRE=portal__destroyClient)]
def portal_scaling_reverse_client(act : ParallelUpdateFrameDelayed;
                                  eid : EntityId;
                                  portal__scales : float2;
                                  portal__curScale : float;
                                  portal__wishScale : float)
  if is_equal_float(portal__curScale, portal__wishScale) && is_equal_float(portal__wishScale, portal__scales.x)
    destroyEntity(eid)
