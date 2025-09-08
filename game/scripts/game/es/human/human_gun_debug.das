options no_aot
require ecs
require Dacoll
require DagorConsole
require game.es.net_console_macro


[console_cmd(name="aim_offset.drawDebug")]
def aim_offset_drawDebug()
  let debugFounded = find_query() <| $ [es(REQUIRE=gun_aim_offset_debug)] (eid : EntityId)
    removeSubTemplate(eid, "gun_aim_offset_debug")
    return true
  if !debugFounded
    find_query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
      addSubTemplate(eid, "gun_aim_offset_debug")
      return true


def human_weap_recoil_set(eid : EntityId;
                          value : bool)
  query(eid) <| $ [es] (var human_weap__recoilEnabled : bool&)
    human_weap__recoilEnabled = value


[net_console_cmd(name="am.weap_recoil_set_server")]
def console_human_weap_recoil_set_server(@net_hero eid : EntityId;
                                         value : bool = true)
  human_weap_recoil_set(eid, value)


[console_cmd(name="am.weap_recoil_set")]
def console_human_weap_recoil_set(value : bool)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    human_weap_recoil_set(eid, value)
    if !is_server()
      exec_server_cmd("am.weap_recoil_set_server :hero: {value}")


[console_cmd(name="am.all_weap_shifts_set")]
def console_all_weap_shifts_set(value : bool)
  console_command("am.heartrate_set {value}")
  console_command("am.hand_stamina_set {value}")
  console_command("am.weap_recoil_set {value}")
