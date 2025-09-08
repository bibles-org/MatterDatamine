require ecs
require app
require PhysVars
require HumanPhys
require Gun
require DagorMath
require DagorSystem
require DngActor
require DngHuman
require DngWeapon
require game.es.human.human_gun_common
require game.es.human.human_reload_common
require game.es.boxed_ammo_reload_common


[es(on_appear, before=anim_phys_init_es)]
def human_weap_anim_init(evt : Event;
                         var human_weap_anim__boltActionVarId : int&;
                         var human_weap_anim__throwProgressVarId : int&;
                         var phys_vars : PhysVars)
  human_weap_anim__boltActionVarId = registerVar(phys_vars, "bolt_action", 0.0)
  human_weap_anim__throwProgressVarId = registerVar(phys_vars, "throw_progress", 0.0)


[es(before=human_gun_attach_es, REQUIRE_NOT=sleeping_monster)]
def human_weap_anim_es(info : UpdateStageInfoAct;
                       human_weap__currentGunSlot : int;
                       human_weap__gunEids : EidList;
                       human_weap_anim__boltActionVarId : int;
                       human_weap_anim__throwProgressVarId : int;
                       human_net_phys : HumanActor;
                       human_weap__throwMode : bool;
                       grenadeThrowProgress : float;
                       animchar__visible : bool = true;
                       animchar__actWhenInvisible = false;
                       var phys_vars : PhysVars;
                       var boltActionProgress : float&;
                       var isGunManualLoadMode : bool&)
  if !animchar__visible && !animchar__actWhenInvisible
    return
  let curSlot = (human_weap__throwMode
                ? int(HUWeaponSlots.EWS_GRENADE)
                : human_weap__currentGunSlot)
  if curSlot < 0
    return

  isGunManualLoadMode = false
  query(human_weap__gunEids[curSlot]) <| $ [es(REQUIRE_NOT=gun_anim__reloadTypes)] (gun : Gun const?;
                                                                                    grenade_thrower : GrenadeThrower const?)
    if gun != null
      if human_weap_anim__boltActionVarId >= 0
        let boltAction = *gun |> gun_lerp_bolt_action_time(info.curTime)
        phys_vars |> setVar(human_weap_anim__boltActionVarId, boltAction)
        isGunManualLoadMode = gun_getFiringMode(*gun, int(gun.firingModeIndex)).modeType == EFiringModeType.EFM_MANUAL
        boltActionProgress = boltAction

    if grenade_thrower != null && human_weap_anim__throwProgressVarId >= 0
      let gtp = ((human_net_phys.role == NetRole.ROLE_REMOTELY_CONTROLLED_SHADOW)
                ? grenadeThrowProgress
                : calc_grenade_throw_progress(*grenade_thrower, info.curTime))
      phys_vars |> setVar(human_weap_anim__throwProgressVarId, gtp)
