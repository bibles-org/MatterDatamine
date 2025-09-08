options no_aot
require ecs
require game.es.net_console_macro


[net_console_cmd(name="am.toggle_jamming")]
def am_toggle_jamming(@net_hero hero_eid : EntityId)
  query(hero_eid) <| $ [es] (human_net_phys__weapEquipCurSlot : int;
                             human_weap__gunEids : EidList)
    let curWeaponEid = human_weap__gunEids[human_net_phys__weapEquipCurSlot]
    query(curWeaponEid) <| $ [es] (var gun_jamming__isJammed : bool&)
      gun_jamming__isJammed = !gun_jamming__isJammed
