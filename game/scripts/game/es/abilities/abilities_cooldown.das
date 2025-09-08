require ecs
require ecs.common
require app
require game.events.events_active_matter
require active_matter.game.es.ability_common


[es(on_appear, tag=server)]
def init_abilities_cooldown(evt : Event;
                            hero_ability__abilities : Array;
                            cooldown_reduction_permanent__value : float = 0.0;
                            var hero_ability__abilitiesCooldown : Object;
                            entity_mods__abilityCooldownMult = 1f)
  for it in hero_ability__abilities
    let ability = get_ecs_object(it)
    var cooldown = get_float(ability, "cooldown") ?? 0.0
    cooldown *= entity_mods__abilityCooldownMult
    cooldown = get_reduced_cooldown(cooldown, cooldown_reduction_permanent__value)
    hero_ability__abilitiesCooldown |> set(get_string(ability, "name", ""), cooldown)


def private set_cooldown(ability_idx : int;
                         cooldown : float;
                         hero_ability__abilities : Array;
                         cooldown_reduction_permanent__value : float = 0.0;
                         var hero_ability__abilitiesCooldown : Object&;
                         var hero_ability__abilitiesNextUseTime : Object&;
                         var hero_ability__lockRecalculateUltCooldown : bool&;
                         entity_mods__abilityCooldownMult = 1f)

  let curTime = get_sync_time()
  let ability = get_ecs_object(hero_ability__abilities[ability_idx])
  var initialCooldown = get_float(ability, "cooldown") ?? 0.0
  initialCooldown *= entity_mods__abilityCooldownMult
  initialCooldown = get_reduced_cooldown(initialCooldown, cooldown_reduction_permanent__value)
  let abilityName = get_string(ability, "name", "")
  let resCooldown = cooldown < 0. ? initialCooldown : cooldown
  hero_ability__abilitiesCooldown |> set(abilityName, resCooldown)

  let nextUseTime = hero_ability__abilitiesNextUseTime |> get_float(abilityName) ?? 10e6f
  let restTime = nextUseTime - curTime
  if restTime > resCooldown
    hero_ability__abilitiesNextUseTime |> set(abilityName, curTime + resCooldown)
  hero_ability__lockRecalculateUltCooldown = cooldown > 0f


[es(tag=server)]
def set_ability_cooldown(evt : CmdSetAbilityCooldown;
                         hero_ability__abilities : Array;
                         cooldown_reduction_permanent__value : float = 0.0;
                         var hero_ability__abilitiesCooldown : Object&;
                         var hero_ability__abilitiesNextUseTime : Object&;
                         var hero_ability__lockRecalculateUltCooldown : bool&;
                         entity_mods__abilityCooldownMult = 1f)
  set_cooldown(evt.idx,
              evt.cooldown,
              hero_ability__abilities,
              cooldown_reduction_permanent__value,
              hero_ability__abilitiesCooldown,
              hero_ability__abilitiesNextUseTime,
              hero_ability__lockRecalculateUltCooldown,
              entity_mods__abilityCooldownMult)
