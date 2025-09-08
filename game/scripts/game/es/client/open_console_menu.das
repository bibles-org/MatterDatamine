require ecs
require game.events.events_active_matter

[es(tag=gameClient, on_event=CmdUse)]
def on_use_console_menu_ui(evt : Event; open_console_menu_on_use__menuName : string)
  broadcastEvent(CmdShowUiMenu(menuName = open_console_menu_on_use__menuName))
