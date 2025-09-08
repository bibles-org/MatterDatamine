options no_aot
require ecs
require game.events.events_active_matter
require game.es.net_console_macro


[net_console_cmd(name="active_matter_balance.set", hint="set active matter for all players")]
def console_active_matter_balance_set(val : int)
  ecs::query() <| $ [es(REQUIRE=possessedByPlr)] (eid : EntityId; am_storage__value : int)
    sendEventImmediate(eid, CmdChangeActiveMatterBalance(change = val - am_storage__value, reason = "server_cheat_active_matter_balance"))


[net_console_cmd(name="active_matter_balance.add", hint="add active matter for all players")]
def console_active_matter_balance_add(val : int)
  ecs::query() <| $ [es(REQUIRE=possessedByPlr, REQUIRE=am_storage__value)] (eid : EntityId)
    sendEventImmediate(eid, CmdChangeActiveMatterBalance(change = val, reason = "server_cheat_active_matter_balance"))


[net_console_cmd(name="am.give_am_full")]
def console_give_am_full(@net_hero hero_eid : EntityId)
  query(hero_eid) <| $ [es] (am_storage__maxValue : int; var am_storage__value : int&)
    am_storage__value = am_storage__maxValue


[net_console_cmd(name="am.give_am_half")]
def console_give_am_half(@net_hero hero_eid : EntityId)
  query(hero_eid) <| $ [es] (am_storage__maxValue : int; var am_storage__value : int&)
    am_storage__value += am_storage__maxValue / 2
    am_storage__value = min(am_storage__value, am_storage__maxValue)


[net_console_cmd(name="am.take_am_full")]
def console_take_am_full(@net_hero hero_eid : EntityId)
  query(hero_eid) <| $ [es] (var am_storage__value : int&)
    am_storage__value = 0

[net_console_cmd(name="am.set_am")]
def console_set_am(amount : int; @net_hero hero_eid : EntityId)
  query(hero_eid) <| $ [es] (var am_storage__value : int&)
    am_storage__value = amount
