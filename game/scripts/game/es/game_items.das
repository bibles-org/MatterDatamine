require ecs
require AnimV20
require DagorSystem
require DagorMath
require Dacoll
require game.events.events_active_matter


[es(on_appear)]
def heal_anim_init_es(evt : Event;
                      item__healAnimEnumName : string;
                      var item__healAnimEnumValue : int&)
  item__healAnimEnumValue = animV20_add_enum_value(item__healAnimEnumName)


[es(on_appear)]
def heal_target_anim_init_es(evt : Event;
                             item__healTargetAnimEnumName : string;
                             var item__healTargetAnimEnumValue : int&)
  item__healTargetAnimEnumValue = animV20_add_enum_value(item__healTargetAnimEnumName)


[es(tag=server, no_order)]
def item_freefalling(act : ParallelUpdateFrameDelayed;
                     eid : EntityId;
                     item_freefalling__stopAt : float;
                     item_freefalling__updateInterval : float;
                     item_freefalling__addHeight : float;
                     item_freefalling__speed : float;
                     var item_freefalling__updateAt : float&;
                     var item_freefalling__targetY : float&;
                     var transform : float3x4)

  var targetValid = true
  if act.curTime >= item_freefalling__updateAt
    item_freefalling__updateAt = act.curTime + item_freefalling__updateInterval

    let tracePos = transform[3]
    let traceDir = float3(0.0, -1.0, 0.0)
    var d = 100.0

    var shapeQueryOutput = ShapeQueryOutput()

    var tracePoint : float3
    var traceNorm : float3
    var traceValid = false
    if traceray_normalized(tracePos, traceDir, d, traceNorm)
      tracePoint = tracePos + traceDir * d
      traceValid = true

    let SPHERE_CAST_MASK = int(PhysLayer.EPL_ALL) & ~(int(PhysLayer.EPL_CHARACTER) | int(PhysLayer.EPL_DEBRIS))
    let targetTracePos = tracePos + traceDir * d
    if d > 1e-3 && sphere_cast_ex(tracePos, targetTracePos, /*radius*/0.01,
                                  shapeQueryOutput, -1, null, SPHERE_CAST_MASK)
      tracePoint = shapeQueryOutput.res
      traceNorm = shapeQueryOutput.norm
      traceValid = true

    if traceValid
      item_freefalling__targetY = (tracePoint + traceNorm * item_freefalling__addHeight).y
    else
      targetValid = false

  if targetValid
    let targetDeltaY = item_freefalling__targetY - transform[3].y
    let deltaY = act.dt * item_freefalling__speed
    if deltaY >= abs(targetDeltaY)
      transform[3].y = item_freefalling__targetY
    else
      transform[3].y += sign(targetDeltaY) * deltaY

  if act.curTime >= item_freefalling__stopAt
    removeSubTemplate(eid, "item_freefalling")