require ecs
require app
require game.events.events_active_matter
require math.base
require game.es.grav_zones_common
require Dacoll
require DagorMath
require DngPhysObj


[es(tag=gameClient, on_appear)]
def phys_water_splasher_appear(evt : Event;
                               transform : float3x4;
                               phys_water_splasher__traceInterval : float;
                               var phys_water_splasher__lastTracePos : float3&;
                               var phys_water_splasher__traceAt : float&)
  phys_water_splasher__traceAt = get_sync_time() + phys_water_splasher__traceInterval
  phys_water_splasher__lastTracePos = transform[3]


[es(tag=gameClient, no_order)]
def phys_obj_water_splasher_update(evt : ParallelUpdateFrameDelayed;
                                   transform : float3x4;
                                   phys_obj_net_phys : PhysObjActor;
                                   phys_water_splasher__traceInterval : float;
                                   phys_water_splasher__fxTemplate : string;
                                   phys_water_splasher__traceDistMin : float;
                                   var phys_water_splasher__lastTracePos : float3&;
                                   var phys_water_splasher__traceAt : float&)
  if phys_obj_net_phys.phys.currentState.isSleep
    return

  if evt.curTime < phys_water_splasher__traceAt
    return

  phys_water_splasher__traceAt = evt.curTime + phys_water_splasher__traceInterval

  let traceFrom = phys_water_splasher__lastTracePos
  let traceTo = transform[3]
  let lenSq = distance_sq(traceFrom, traceTo)
  if lenSq < phys_water_splasher__traceDistMin
    return

  let waterLen = sqrt(lenSq)
  var t = waterLen
  if traceray_water_at_time(traceFrom, traceTo, evt.curTime, t)
    createEntity(phys_water_splasher__fxTemplate) <| $ [es] (var init : ComponentsInitializer)
      let traceDir = (traceTo - traceFrom) / waterLen
      init |> set("transform", get_grav_tm(traceFrom + t * traceDir))

  phys_water_splasher__lastTracePos = traceTo

