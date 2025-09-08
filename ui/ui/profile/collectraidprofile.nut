import "%dngscripts/ecs.nut" as ecs

let getLoadoutQuery = ecs.SqQuery("getLoadoutQuery", {comps_ro=[["player_profile__loadout", ecs.TYPE_ARRAY]]})

return @() getLoadoutQuery.perform(@(_eid, comps) comps.player_profile__loadout.getAll())