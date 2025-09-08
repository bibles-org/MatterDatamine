require ecs
require ecs.common
require math.base
require app
require game.events.events_active_matter
require PhysMat
require Dacoll


[es(tag=gameClient, on_appear)]
def init_help_sings_tracer(evt : Event;
                           help_sign_tracer__traceMaterial : string;
                           var help_sign_tracer__traceMaterialId : int&)
  help_sign_tracer__traceMaterialId = get_material_id(help_sign_tracer__traceMaterial)


[es(tag=gameClient, no_order)]
def trace_help_signs(info : ParallelUpdateFrameDelayed;
                     transform : float3x4;
                     help_sign_tracer__traceStartOffset : float3;
                     help_sign_tracer__tracePeriod : float;
                     help_sign_tracer__traceMaterialId : int;
                     var help_sign_tracer__nextTraceAt : float&)
  if info.curTime < help_sign_tracer__nextTraceAt
    return

  help_sign_tracer__nextTraceAt = info.curTime + help_sign_tracer__tracePeriod
  let tracePos = help_sign_tracer__traceStartOffset + transform[3]
  query() <| $ [es] (help__visible : bool;
                     help__requireTrace : bool;
                     help__shortDistance : float;
                     transform aka help_transform : float3x4;
                     var help__traceSuccess : bool&)
    if !help__visible || !help__requireTrace
      return

    let vector = help_transform[3] - tracePos
    let distSq = length_sq(vector)
    if distSq > square(help__shortDistance)
      help__traceSuccess = false
      return

    let dist = sqrt(distSq)
    let traceDir = vector / dist
    help__traceSuccess = !rayhit_normalized(tracePos, traceDir, dist, ETF_DEFAULT, help_sign_tracer__traceMaterialId)
