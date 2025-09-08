options no_aot
require ecs
require game.utils.sound_utils
require DagorConsole


[console_cmd(name="snd.broadcast_scene_sound")]
def console_snd_play_scene_sound_debug(desc : string)
  broadcast_scene_net_sound(desc, float3(0., 0., 0.))
