require ecs
require danetlibs.imgui_daeditor.imgui.daEditor.ecs_inspectors_common
require debugapi
require game.es.daEditor.entities_extra_name_common


def get_entity_extra_name_out(eid : EntityId; var out_string : string?)
  *out_string = get_entity_extra_name_common(eid)

[init, export]
def init_entity_extra_name_getter()
  unsafe
    lock_debug_agent() <| $()
      start_ecs_inspectors_agent()
      if not_in_ecs_inspectors_context() && !is_in_aot()
        set_entity_name_getter(@@get_entity_extra_name_out, this_context())
