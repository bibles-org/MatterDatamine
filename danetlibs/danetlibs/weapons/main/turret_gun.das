require ecs
require Gun
require DagorSystem
require DagorRandom
require DaWeapons
require DagorMath
require DaWeaponProps
require BallisticsProps
require AnimV20
require GeomNodeTree

[cpp_event(unicast)]
struct EventOnGunCreated
  gunEid : ecs::EntityId

[cpp_event(unicast)]
struct EventOnGunPayloadCreated
  gunEid : EntityId
  index : int
  pos_in : float3
  mass_in : float
  drag_in : float
  ammo_in : int

[es(after=gun_init_es, on_event=EventOnTurretControlCreated)]
def turret_gun_controls_created(evt : Event;
                                eid : EntityId;
                                turret__owner : EntityId)
  sendEvent(turret__owner, EventOnGunCreated(gunEid = eid))


[es(REQUIRE=animchar)]
def turret_control_es(evt : EventOnGunCreated)
  query(evt.gunEid) <| $ [es] (gun__shootNodeName : string;
                               turret__emitterOwner : EntityId;
                               var gun : Gun)
    query(turret__emitterOwner) <| $ [es] (animchar : AnimcharBaseComponent)
      gun |> gun_loadShootNode(gun__shootNodeName, *animchar.nodeTree)

  query(evt.gunEid) <| $  [es(REQUIRE_NOT=gun__isLauncher)] (eid : EntityId;
                                                             turret__owner : EntityId;
                                                             gun : Gun;
                                                             gun__ammo : int;
                                                             turret__id : int;
                                                             gun__shell_prop_ids : GunShellPropIds;
                                                             turret__emitterOwner : EntityId;
                                                             gun__isPayload : bool = true)
    if !gun__isPayload
      return
    query(turret__emitterOwner) <| $ [es] (animchar : AnimcharBaseComponent)
      assume shellId = gun__shell_prop_ids[0]
      projectile_get_props(int(shellId.shellId)) <| $(projectileProps : ProjectileProps)
        var tm : float3x4
        animchar |> animchar_get_tm(tm)
        let pos = gun.shootNodeData |> calcRootRelativeShootPos(*animchar.nodeTree)
        let posLoc = rotate(inverse(tm), pos)
        sendEvent(turret__owner, EventOnGunPayloadCreated(gunEid = eid, index = turret__id, pos_in = posLoc, mass_in = projectileProps.mass, drag_in = 0.0f, ammo_in = gun__ammo))

  query(evt.gunEid) <| $  [es(REQUIRE=gun__isLauncher)] (eid : EntityId;
                                                         turret__owner : EntityId;
                                                         gun : Gun;
                                                         gun__ammo : int;
                                                         turret__id : int;
                                                         gun__shell_prop_ids : GunShellPropIds;
                                                         turret__emitterOwner : EntityId;
                                                         gun__isPayload : bool = true)
    if !gun__isPayload
      return
    query(turret__emitterOwner) <| $ [es] (animchar : AnimcharBaseComponent)
      assume shellId = gun__shell_prop_ids[0]
      if int(shellId.shellId) < 0
        return
      shell_get_props(int(shellId.shellId)) <| $(bombBallisticsProps : ShellProps)
        shell_payload_get_props(int(shellId.shellId)) <| $(shellPayloadProps : ShellPayloadProps)
          var tm : float3x4
          animchar |> animchar_get_tm(tm)
          let pos = gun.shootNodeData |> calcRootRelativeShootPos(*animchar.nodeTree)
          let posLoc = rotate(inverse(tm), pos)
          sendEvent(turret__owner, EventOnGunPayloadCreated(gunEid = eid, index = turret__id, pos_in = posLoc, mass_in = bombBallisticsProps.ballisticProps.mass, drag_in = shellPayloadProps.dragCx, ammo_in = gun__ammo))

[es(on_appear, after=gun_init_es, REQUIRE=isTurret)]
def turret_gun_es(evt : Event;
                  eid : EntityId;
                  turret__owner : EntityId;
                  gun__maxAmmo : int;
                  gun__shell_prop_ids : GunShellPropIds;
                  gun__shellsAmmo : Array;
                  var gun : Gun&;
                  var gun__ammo : int&;
                  var gun__curShellId : ShellPropIds&;
                  var gun__ammo_by_shell : IntList&)
  if gun__shell_prop_ids |> length() == 0
    logerr("Removed bad gun entity {eid} with missing shell props of template {getEntityTemplateName(eid)}")
    destroyEntity(eid)
    return

  assume shellId = gun__shell_prop_ids[0]

  gun__ammo = gun__maxAmmo
  gun__ammo_by_shell |> resize(length(gun__shellsAmmo))
  for shellType in range(0, length(gun__shellsAmmo))
    gun__ammo_by_shell[shellType] = get_int(gun__shellsAmmo[shellType]) ?? -1
  if gun__ammo_by_shell |> length() > 0
    gun__ammo = min(gun__ammo_by_shell[0], gun__ammo)
  gun__curShellId = shellId

  gun.curState.loaded = (gun__ammo != 0)

  sendEvent(turret__owner, EventOnGunCreated(gunEid = eid))
