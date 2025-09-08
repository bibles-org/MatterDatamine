options no_aot
require ecs
require strings
require DngHuman
require DagorConsole
require DagorMath
require DagorDebug3D
require ecs.soa_template
require game.es.net_console_macro
require game.events.events_game
require game.events.events
require game.utils.net_utils


[console_cmd(name="am.heartrate_debug")]
def console_heartrate_debug()
  query() <| $ [es(REQUIRE=hero)] (var heartrate__showStamina : bool&)
    heartrate__showStamina = !heartrate__showStamina


[net_console_cmd(name="am.heartrate_fully_rested")]
def console_heartrate_fully_rested(@net_hero eid : EntityId)
  query(eid) <| $ [es] (var heartrate__stamina : float&;
                        var heartrate__value : float&;
                        var heartrate__amortization : float&;
                        heartrate__range : float2;
                        heartrate__maxStamina : float)
    heartrate__stamina = heartrate__maxStamina
    heartrate__value = heartrate__range.x
    heartrate__amortization = .0


[net_console_cmd(name="am.heartrate_fully_tired")]
def console_heartrate_fully_tired(@net_hero eid : EntityId)
  query(eid) <| $ [es] (var heartrate__stamina : float&;
                        var heartrate__value : float&;
                        heartrate__range : float2)
    heartrate__stamina = .0
    heartrate__value = heartrate__range.y


def heartrate_toogle(eid : EntityId)
  query(eid) <| $ [es] (var heartrate__stamina : float&;
                        var heartrate__value : float&;
                        var heartrate__riseSpeedMulti : float&;
                        var heartrate__riseSpeedMultiDefault : float&;
                        var heartrate__riseSpeedMultiDebugValue : float&;
                        heartrate__maxStamina : float;
                        heartrate__range : float2)
    if heartrate__riseSpeedMultiDebugValue == .0 // disable
      heartrate__riseSpeedMultiDebugValue = heartrate__riseSpeedMultiDefault
      heartrate__riseSpeedMulti = .0
      heartrate__riseSpeedMultiDefault = .0
      heartrate__stamina = heartrate__maxStamina
      heartrate__value = heartrate__range.x
    else  //enable
      heartrate__riseSpeedMultiDefault = heartrate__riseSpeedMultiDebugValue
      heartrate__riseSpeedMultiDebugValue = .0
      sendEvent(eid, EventOnModsChanged())


def heartrate_set(eid : EntityId;
                  value : bool)
  query(eid) <| $ [es] (heartrate__riseSpeedMultiDebugValue : float)
    let isHeartrateEnabled = (heartrate__riseSpeedMultiDebugValue == 0.0)
    if value != isHeartrateEnabled
      heartrate_toogle(eid)


[net_console_cmd(name="am.heartrate_toggle_server")]
def console_heartrate_toggle_server(@net_hero eid : EntityId)
  heartrate_toogle(eid)


[console_cmd(name="am.heartrate_toggle")]
def console_heartrate_toggle()
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    heartrate_toogle(eid)
    if !is_server()
      exec_server_cmd("am.heartrate_toggle_server :hero:")


[net_console_cmd(name="am.heartrate_set_server")]
def console_heartrate_set_server(@net_hero eid : EntityId;
                                 value : bool = true)
  heartrate_set(eid, value)


[console_cmd(name="am.heartrate_set")]
def console_heartrate_set(value : bool)
  query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    heartrate_set(eid, value)
    if !is_server()
      exec_server_cmd("am.heartrate_set_server :hero: {value}")


[es(tag=(dev, gameClient), after=hearbeat_mod_jumpspeed_client, REQUIRE=watchedByPlr)]
def display_debug_heartrate_stamina(act : UpdateStageInfoAct;
                                    heartrate__showStamina : bool;
                                    heartrate__stamina : float;
                                    heartrate__staminaRate : float;
                                    heartrate__debugInfoTarget : float4;
                                    heartrate__amortization : float;
                                    heartrate__maxStamina : float;
                                    human_breath__recoverBreathMult : float;
                                    human_damage_model__sumHpAllBodyParts : float;
                                    human_damage_model__sumMaxHpAllBodyParts : float;
                                    heartrate__damagedStaminaPow : float;
                                    heartrate__damagedStaminaMaxMulti : float;
                                    human_dodge__dodgeSpdMulti : float;
                                    human_net_phys : HumanActor)
  if !heartrate__showStamina
    return
  assume state = human_net_phys.phys.currentState
  var text = "stamina: {int(heartrate__stamina)} / {int(heartrate__maxStamina)}"
  var h = 120.0
  let step = 17.0
  add_debug_text_mark_screen(80.0, h, text, -1, 0.f, E3DCOLOR(0xffffffff))
  h += step
  add_debug_text_mark_screen(80.0, h, "StamRt:" + fmt(":.2f", heartrate__staminaRate), -1, 0.f, E3DCOLOR(0xffffffff))
  h += step
  add_debug_text_mark_screen(80.0, h, "target:" + fmt(":.0f", heartrate__debugInfoTarget.w), -1, 0.f, E3DCOLOR(0xffffffff))
  h += step
  text = "m:" + fmt(":.0f", heartrate__debugInfoTarget.x) + " a:" + fmt(":.0f", heartrate__debugInfoTarget.y)
  if heartrate__debugInfoTarget.z > .0
    text += " f:" + fmt(":.0f", heartrate__debugInfoTarget.z)
  add_debug_text_mark_screen(80.0, h, text, -1, 0.f, E3DCOLOR(0xffffffff))
  h += step
  add_debug_text_mark_screen(80.0, h, "amort : " + fmt(":.0f", heartrate__amortization), -1, 0.f, E3DCOLOR(0xffffffff))
  h += step
  var damagedStaminMulti = cvt(pow(human_damage_model__sumHpAllBodyParts, heartrate__damagedStaminaPow),
                              pow(human_damage_model__sumMaxHpAllBodyParts, heartrate__damagedStaminaPow), .0,
                              1.0, heartrate__damagedStaminaMaxMulti)
  damagedStaminMulti = heartrate__staminaRate > 0.0 ? 1.0 / damagedStaminMulti : damagedStaminMulti
  add_debug_text_mark_screen(80.0, h, "dmgMul: " + fmt(":.2f", damagedStaminMulti), -1, 0.f, E3DCOLOR(0xffffffff))
  h += step
  h += step
  add_debug_text_mark_screen(80.0, h, "sprint: " + fmt(":.2f", state.sprintSpeedMult), -1, 0.f, E3DCOLOR(0xffffffff))
  h += step
  add_debug_text_mark_screen(80.0, h, "aim   : " + fmt(":.2f", state.breathShakeMult), -1, 0.f, E3DCOLOR(0xffffffff))
  h += step
  add_debug_text_mark_screen(80.0, h, "climb : " + fmt(":.2f", state.climbingSpeedMult), -1, 0.f, E3DCOLOR(0xffffffff))
  h += step
  add_debug_text_mark_screen(80.0, h, "jump  : " + fmt(":.2f", state.jumpSpeedMult), -1, 0.f, E3DCOLOR(0xffffffff))
  h += step
  add_debug_text_mark_screen(80.0, h, "pose  : " + fmt(":.2f", state.fasterChangePoseMult), -1, 0.f, E3DCOLOR(0xffffffff))
  h += step
  add_debug_text_mark_screen(80.0, h, "breath: " + fmt(":.2f", human_breath__recoverBreathMult), -1, 0.f, E3DCOLOR(0xffffffff))
  h += step
  add_debug_text_mark_screen(80.0, h, "dodge : " + fmt(":.2f", human_dodge__dodgeSpdMulti), -1, 0.f, E3DCOLOR(0xffffffff))
  h += step
