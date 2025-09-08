options no_aot
require DagorConsole
require game.es.net_console_macro

[console_cmd(name="net.timeSpeed")]
def console_net_time_speed(time_speed : float)
  console_command("app.timeSpeed {time_speed}")
  console_command("server.cmd app.timeSpeed {time_speed}")
