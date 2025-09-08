require ecs
require DngHuman
require DngWeapon
require game.es.boxed_ammo_reload_common


[es(before=human_weap_anim_es)]
def set_grenade_reload_anim_state_to_current_gun(info : UpdateStageInfoAct;
                                                 human_weap__currentGunSlot : int;
                                                 human_weap__gunEids : EidList;
                                                 human_net_phys : HumanActor;
                                                 human_weap__throwMode : bool;
                                                 isInVehicle : bool = false;
                                                 animchar__visible : bool = true;
                                                 animchar__actWhenInvisible = false)
  if !animchar__visible && !animchar__actWhenInvisible
    return
  if human_weap__currentGunSlot < 0
    return

  if !human_weap__throwMode
    query(human_weap__gunEids[human_weap__currentGunSlot]) <| $ [es(REQUIRE_NOT=gun_anim__reloadTypes)] (grenade_thrower__projectileEntity : EntityId)
      query(grenade_thrower__projectileEntity) <| $ [es] (var slot_attach__visible : bool&)
        let weaponSlot = determine_current_weapon_slot(info.curTime, human_net_phys)
        slot_attach__visible = (weaponSlot == HUWeaponSlots.EWS_GRENADE) && !isInVehicle
