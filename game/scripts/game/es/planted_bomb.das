require app
require ecs
require game.events.events
require game.events.events_active_matter
require NetPropsRegistry
require DagorSystem


[es(tag=server, on_appear)]
def planted_bomb_appear(evt : Event;
                        planted_bomb__explTime : float;
                        phys_obj_net_phys__blk : string;
                        var shell__shell_id__ballistics_id : int&;
                        var shell__shell_id__damage_id : int&;
                        var shell__shell_id__shell_id : int&;
                        var shell__launchAtTime : float&;
                        var shell__explTime : float&;
                        var active : bool&)
  shell__shell_id__ballistics_id = register_net_props(phys_obj_net_phys__blk, "shell")
  shell__shell_id__damage_id = register_net_props(phys_obj_net_phys__blk, "damage")
  shell__shell_id__shell_id = register_net_props(phys_obj_net_phys__blk, "ballistics")

  shell__launchAtTime = get_sync_time()
  shell__explTime = get_sync_time() + planted_bomb__explTime
  active = true
