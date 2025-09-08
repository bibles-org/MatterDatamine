options no_aot

require ecs
require DagorEditor


// DagorEditor module isn't present in some game configurations
// yet it might be useful to know if editor is activated
// so in those places editor_active_marker__isActive component can be queried
[es(no_order)]
def update_editor_active_marker(upd : UpdateStageInfoAct; var editor_active_marker__isActive : bool&)
  editor_active_marker__isActive = is_editor_activated()


[es(on_event=EventLevelLoaded, tag=gameClient)]
def create_editor_active_marker(evt : Event)
  createEntity("editor_active_marker")
