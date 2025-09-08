require ecs
require game.events.events_game
require DngHuman
require HumanPhys
require game.es.human.human_gun_common


[es]
def human_gun_to_phys_params(evt : CmdWeapAttach;
                             weap__sprintLerpFactor : float = 1.0;
                             gun__adsSpeedMult : float = 1.0;
                             gun_entity_mods__adsSpeedMult : float = 1.0)
  if evt.isAttached && evt.slotId != int(HUWeaponSlots.EWS_GRENADE)
    query(evt.toEid) <| $ [es] (var human_net_phys : HumanActor)
      human_net_phys.phys.currentState.sprintLerpSpeedMult = weap__sprintLerpFactor
      human_net_phys.phys.aimSpeed = calc_human_net_phys_aim_speed(human_net_phys,
                                                                   gun__adsSpeedMult,
                                                                   gun_entity_mods__adsSpeedMult)

[es(track=gun_entity_mods__adsSpeedMult)]
def human_gun_to_phys_params_track_ads_speed_mult(evt : Event;
                                                  slot_attach__attachedTo : EntityId;
                                                  gun__adsSpeedMult : float = 1.0;
                                                  gun_entity_mods__adsSpeedMult : float)
  query(slot_attach__attachedTo) <| $ [es] (var human_net_phys : HumanActor)
    human_net_phys.phys.aimSpeed = calc_human_net_phys_aim_speed(human_net_phys,
                                                                gun__adsSpeedMult,
                                                                gun_entity_mods__adsSpeedMult)


[es(track=human_unarmed__active)]
def human_unarmed_sprint(evt : Event; human_unarmed__active : bool; var human_net_phys : HumanActor)
  if human_unarmed__active
    human_net_phys.phys.currentState.sprintLerpSpeedMult = 1.f
