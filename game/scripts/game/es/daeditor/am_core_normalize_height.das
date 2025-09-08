require ecs
require Dacoll
require level
require DagorSystem
require DagorEditor


[es(tag=(server, dev), on_appear, on_event=EventLevelLoaded)]
def am_core_height_normalize(evt : Event; am_core__minHeight : float; eid : EntityId; var transform : float3x4&)
  if !is_level_loaded()
    return
  var height = 100f
  var newPos = transform[3]
  if tracedown_normalized(transform[3], height, ETF_DEFAULT)
    if height < am_core__minHeight - 0.1f
      newPos.y = transform[3].y - height + am_core__minHeight
      logerr("{eid}: {getEntityTemplateName(eid)} too low and should be normalized. old pos {transform[3]} new pos {newPos} {height}")
      transform[3] = newPos
      entity_obj_editor_saveComponent(eid, "transform")