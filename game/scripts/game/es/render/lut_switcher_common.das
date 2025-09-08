module lut_switcher_common shared
require ecs
require ecs.safe
require ecs.common


def add_grading(item_id : uint;
                var color_grading_items : ecs::Array;
                color_grading : Object)
  let priority = color_grading.priority ?? 0
  var insertPos = length(color_grading_items)
  for colorGradingIndex in iter_range(color_grading_items)
    if (color_grading_items[colorGradingIndex] as Object)?.priority ?? 0 > priority
      insertPos = colorGradingIndex
      break

  push(color_grading_items, insertPos, color_grading)
  var itemObj = getRW_ecs_object(color_grading_items[insertPos])
  set(*itemObj, "unique_id", int(item_id))


def add_grading(item_id : uint;
                color_grading : Object)
  find_query() <| $ [es] (var color_grading_items : Array)
    add_grading(item_id, color_grading_items, color_grading)
    return true


def remove_grading(item_id : uint;
                   var color_grading_items : ecs::Array)
  var idx = length(color_grading_items)
  while --idx >= 0
    var itemObj = getRW_ecs_object(color_grading_items[idx])
    if uint((*itemObj).unique_id ?? 0) == item_id
      let timingsPtr = get_Point3(*itemObj, "timings")
      if timingsPtr != null && (*timingsPtr).z > 0f
        let timings = *timingsPtr
        let lifeTime = (*itemObj).life_time ?? 0f
        if lifeTime < timings.x + timings.y
          set(*itemObj, "life_time", timings.x + timings.y) // advance to end
      else
        erase(color_grading_items, idx)


def remove_grading(item_id : uint)
  find_query() <| $ [es] (var color_grading_items : Array)
    remove_grading(item_id, color_grading_items)
    return true


def update_grading(item_id : uint;
                   var color_grading_items : ecs::Array;
                   color_grading : Object)
  for itemCmp in color_grading_items
    var itemObj = itemCmp as Object
    if uint(itemObj?.unique_id ?? 0) == item_id
      update_object_existing_fields_from(*itemObj, color_grading)


def update_grading(item_id : uint;
                   color_grading : Object)
  find_query() <| $ [es] (var color_grading_items : Array)
    update_grading(item_id, color_grading_items, color_grading)
    return true


def amend_object_from(var to; from)
  for field in from
    set(to, field.key, field.value)

def update_object_existing_fields_from(var to; from)
  for field in from
    if has(to, field.key)
      deref(to[field.key]) := field.value

def switch_color_grading(item_id : uint;
                         var color_grading_items : Array;
                         color_grading : Object;
                         is_enabled : bool)
  if is_enabled
    add_grading(item_id, color_grading_items, color_grading)
  else
    remove_grading(item_id, color_grading_items)

def has_color_grading(color_grading_items : Array; item_id : uint)
  for it in color_grading_items
    if uint(get_ecs_object(it)?.unique_id ?? 0) == item_id
      return true
  return false
