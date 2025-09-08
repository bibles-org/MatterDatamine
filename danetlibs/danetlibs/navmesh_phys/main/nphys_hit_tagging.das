require ecs
require app
require DngDm
require danetlibs.navmesh_phys.main.nphys_events
require danetlibs.navmesh_phys.main.nphys_common


def get_weapon_eid_by_props_shell_id(human_weap__gunEids : EidList; human_weap__currentGunEid : EntityId; gun_props_id, shell_id : int16)
  if int(gun_props_id) == -1 && int(shell_id) == -1
    return human_weap__currentGunEid

  for gun in human_weap__gunEids
    if get_int(gun, "gun__propsId") ?? -1 == int(gun_props_id)
      return gun
  return INVALID_ENTITY_ID


[es(tag=server, no_order, REQUIRE_NOT=(deadEntity, nphys__disabled))]
def nphys_hit_tagging_remove(info : ecs::UpdateStageInfoAct&;
                             eid : EntityId;
                             navmesh_phys__hitTagEnd : float;
                             navmesh_phys__walkSpeedModHitTagMultName : string;
                             var navmesh_phys__walkSpeedMods : Object)
  if info.curTime >= navmesh_phys__hitTagEnd
    set_mod_mult_value(navmesh_phys__walkSpeedMods, navmesh_phys__walkSpeedModHitTagMultName, 1.0, eid)


[es(tag=server)]
def nphys_hit_tagging_applier_es(evt : EventOnEntityHit;
                                 eid : EntityId;
                                 navmesh_phys__hitTagPower : float = 0.f;
                                 navmesh_phys__hitTagDuration : float = 0.f;
                                 navmesh_phys__walkSpeedModHitTagMultName : string;
                                 var navmesh_phys__hitTagEnd : float&;
                                 var navmesh_phys__walkSpeedMods : Object)
  if eid != evt.victim
    return
  var isTaggingGun = false
  assume damageType = evt.damageType
  var walkSpeedHitTagMult = 1.0
  var durationMult = 1.0
  if damageType == int(DamageType.DM_PROJECTILE)
    query(evt.offender) <| $ [es] (human_weap__gunEids : EidList; human_weap__currentGunEid : EntityId)
      let weaponEid = get_weapon_eid_by_props_shell_id(human_weap__gunEids, human_weap__currentGunEid,
                                                       int16(evt.gunPropsId), int16(evt.shellId))
      isTaggingGun = query(weaponEid) <| $ [es] (gun__hitTagPower : float;
                                                 gun__hitTagDuration : float = 0.0;
                                                 gun__hitTagDurationMult : float = 1.0)
        walkSpeedHitTagMult *= gun__hitTagPower
        navmesh_phys__hitTagEnd = max(navmesh_phys__hitTagEnd, get_sync_time() + gun__hitTagDuration)
        durationMult = gun__hitTagDurationMult

  walkSpeedHitTagMult *= navmesh_phys__hitTagPower
  navmesh_phys__hitTagEnd = max(navmesh_phys__hitTagEnd, get_sync_time() + navmesh_phys__hitTagDuration * durationMult)
  set_mod_mult_value(navmesh_phys__walkSpeedMods, navmesh_phys__walkSpeedModHitTagMultName, walkSpeedHitTagMult, eid)
