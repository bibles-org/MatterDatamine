options no_aot
require ecs
require strings
require DagorSystem
require game.events.events_active_matter
require game.es.net_console_macro


[net_console_cmd(name="abilities.reset_cooldown", hint="arg < 0 - restore initial cooldown")]
def reset_ultimate_cooldown(val : float = 0f)
  query() <| $ [es(REQUIRE=hero_ability__abilitiesCooldown)] (eid : EntityId; hero_ability__abilities : Array)
    for i in iter_range(hero_ability__abilities)
      sendEvent(eid, CmdSetAbilityCooldown(cooldown = val, idx = i))


[net_console_cmd(name="abilities.start_ability")]
def start_ability(req_name : string = ""; @net_hero eid : EntityId)
  query(eid) <| $ [es] (hero_ability__abilities : Array)
    for i in iter_range(hero_ability__abilities)
      let name = get_string(get_ecs_object(hero_ability__abilities[i]), "name", "")
      if name == req_name
        sendEvent(eid, CmdUseAbilityIdx(idx = i))
        return
    let str = build_string() <| $(var s)
      s |> write("Use one of available ability name: ")
      var first = true
      for it in hero_ability__abilities
        if !first
          s |> write(", ")
        first = false
        s |> write(get_string(get_ecs_object(it), "name", ""))
      s |> write("\n")
    logerr(str)


[net_console_cmd(name="abilities.disable_active_abilities")]
def disable_active_abilities_cmd()
  query() <| $ [es(REQUIRE=hero_ability__abilitiesState)] (eid : EntityId)
    sendEventImmediate(eid, DisableActiveAbilities())