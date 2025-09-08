require ecs
require ecs.common
require game.events.events


[es(tag=server)]
def recharge_ability(evt : EventEntityCreated; game_effect__attachedTo : EntityId;
                     hero_ability__rechargeAbilityType : string; hero_ability__rechargeAmount : int)
  query(game_effect__attachedTo) <| $ [es] (hero_ability__abilities : Array; var hero_ability__abilitiesSpentCharges : Object&)
    for it in hero_ability__abilities
      let state = get_ecs_object(it)
      if get_string(state, "type", "") == hero_ability__rechargeAbilityType
        let name = get_string(state, "name", "")
        let newCharge = max(0, get_int(hero_ability__abilitiesSpentCharges, name) ?? 0 - hero_ability__rechargeAmount)
        hero_ability__abilitiesSpentCharges |> set(name, newCharge)
        break


[es(tag=server, no_order)]
def autorecharge_ability(act : UpdateStageInfoAct; isAlive : bool;
                         hero_ability__abilities : Array;
                         hero_ability__abilitiesNextUseTime : Object;
                         var hero_ability__abilitiesSpentCharges : Object&)
  if !isAlive || length(hero_ability__abilitiesNextUseTime) == 0
    return

  for it in hero_ability__abilities
    let ability = get_ecs_object(it)
    let maxCharges = get_int(ability, "maxCharges") ?? 0
    if maxCharges <= 0
      continue
    let name = get_string(ability, "name", "")
    let spentCharges = get_int(hero_ability__abilitiesSpentCharges, name) ?? 0
    let noMoreCharges = spentCharges == maxCharges
    if !noMoreCharges
      continue
    let autoRecharge = get_int(ability, "autoRecharge") ?? 0
    if autoRecharge <= 0
      continue
    let nextUse = get_float(hero_ability__abilitiesNextUseTime, name) ?? act.curTime
    if nextUse <= act.curTime
      hero_ability__abilitiesSpentCharges |> set(name, max(0, spentCharges - autoRecharge))
