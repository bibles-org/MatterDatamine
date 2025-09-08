require ecs
require ecs.common
require ecs.safe
require game.events.inventory_events
require game.events.events_active_matter
require net


[es(tag=server)]
def interrupt_actions_on_boxed_ammo_gun_reload_started(evt : CmdHeroGunWithBoxedAmmoReloadStarted;
                                                       eid : EntityId;
                                                       resources_gatherer_hero_debug : Tag const?)
  if resources_gatherer_hero_debug != null
    print("[RESOURCES GATHERER DEBUG] CmdHeroGunWithBoxedAmmoReloadStarted blocked resources gathering for actor {eid}")

  send_net_event(eid, CmdGathererToggle(isOn = false))


[es(tag=server)]
def interrupt_actions_on_weapon_mod_equip_started(evt : CmdWeaponModEquipStarted;
                                                  eid : EntityId;
                                                  resources_gatherer_hero_debug : Tag const?)
  if resources_gatherer_hero_debug != null
    print("[RESOURCES GATHERER DEBUG] CmdWeaponModEquipStarted blocked resources gathering for actor {eid}")

  send_net_event(eid, CmdGathererToggle(isOn = false))