require ecs
require game.events.events_active_matter
require game.events.events_game
require game.es.human.human_use_object_common
require game.es.am_interactable_common
require game.es.human_weap_common
require app
require inventory
require DaWeaponProps
require DngNet
require game.events.events
require game.events.inventory_events


def has_holder(hero_eid : EntityId;
               holder_id : int)
  var result = false
  query(hero_eid) <| $ [es] (itemContainer : EidList)
    for itemEid in itemContainer
      query(itemEid) <| $ [es] (ammo_holder__id : int = INVALID_ITEM_ID)
        if ammo_holder__id == holder_id
          result = true
      if result
        break
  return result


def ammo_loaded(hero_eid : EntityId;
                holder_id : int)
  var result = false
  query(hero_eid) <| $ [es] (human_weap__currentGunEid : EntityId)
    query(human_weap__currentGunEid) <| $ [es] (gun__totalAmmo : int;
                                                gun__ammo : int;
                                                gun__ammoHolderIds : IntList)
      result = (!empty(gun__ammoHolderIds) &&
                gun__ammoHolderIds[0] == holder_id &&
                (gun__ammo > 0 || gun__totalAmmo > 0))
  return result


def find_holder(hero_eid : EntityId;
                holder_id : int)
  var result = INVALID_ENTITY_ID
  query(hero_eid) <| $ [es] (itemContainer : EidList)
    for itemEid in itemContainer
      query(itemEid) <| $ [es] (ammo_holder__id : int = INVALID_ITEM_ID)
        if ammo_holder__id == holder_id
          result = itemEid
      if result != INVALID_ENTITY_ID
        break
  return result


[es(tag=server, REQUIRE=revive_ammo__selectAction)]
def on_revive_ammo_select_action(evt : CmdExecInteractionAction;
                                 interactable_invoice__hero : EntityId)
  query(interactable_invoice__hero) <| $ [es] (resurrection__usableEid : EntityId)
    sendEvent(resurrection__usableEid, CmdUse(requesterEid = interactable_invoice__hero))


[es(tag=server, REQUIRE=select_launcher_ammo, REQUIRE_NOT=revive_ammo__selectAction)]
def on_not_revive_ammo_select_action(evt : CmdExecInteractionAction;
                                     interactable_invoice__hero : EntityId)
  query(interactable_invoice__hero) <| $ [es] (var resurrection__targetPlayerEid : EntityId&)
    resurrection__targetPlayerEid = INVALID_ENTITY_ID


[es(tag=server, track=human_use_object__currentInteractable)]
def am_launcher_reload_request(evt : Event;
                               eid : EntityId;
                               human_use_object__currentInteractable : EntityId;
                               human_weap__currentGunEid : EntityId)
  if human_use_object__currentInteractable != INVALID_ENTITY_ID
    return
  query(human_weap__currentGunEid) <| $ [es] (var am_launcher__reloadAmmoEid : EntityId&)
    if am_launcher__reloadAmmoEid == INVALID_ENTITY_ID
      return
    send_net_event(eid, CmdLoadAmmoFromInventoryToGun(ammoEid = am_launcher__reloadAmmoEid, gunEid = human_weap__currentGunEid))

    am_launcher__reloadAmmoEid = INVALID_ENTITY_ID


[es(tag=server, REQUIRE=select_launcher_ammo)]
def on_ammo_select_action_common(evt : CmdExecInteractionAction;
                                 interactable_invoice__hero : EntityId;
                                 ammo_holder__id : int;
                                 ammo_holder__templateName : string;
                                 item__shell : string;
                                 shell_props : ShellPropIds;
                                 launcher_ammo__gunTemplate : string)
  query(interactable_invoice__hero) <| $ [es] (human_weap__currentGunEid : EntityId)
    let launcherEid = human_weap__currentGunEid
    query(launcherEid) <| $ [es] (var gun__ammoHolders : StringList;
                                  var gun__ammoHolderIds : IntList;
                                  var gun__shells : Array;
                                  var gun__shell_prop_ids : GunShellPropIds;
                                  var am_launcher__gunTemplate : das_string&;
                                  var am_launcher__reloadAmmoEid : EntityId&)
      am_launcher__gunTemplate := launcher_ammo__gunTemplate

      if empty(gun__ammoHolderIds) || gun__ammoHolderIds[0] != ammo_holder__id
        gun__ammoHolderIds |> clear()
        gun__ammoHolderIds |> push(ammo_holder__id)
        gun__ammoHolders |> clear()
        gun__ammoHolders |> push(ammo_holder__templateName)
        gun__shells |> clear()
        gun__shells |> push(item__shell)
        gun__shell_prop_ids |> clear()
        gun__shell_prop_ids |> push(shell_props)
        am_launcher__reloadAmmoEid = find_holder(interactable_invoice__hero, ammo_holder__id)


[es(tag=server, no_order, REQUIRE=revive_ammo__selectAction)]
def update_revive_invoice_availability(info : ParallelUpdateFrameDelayed;
                                       interactable_invoice__hero : EntityId;
                                       ammo_holder__id : int;
                                       var interactable_invoice__available : bool&)
  interactable_invoice__available = has_holder(interactable_invoice__hero, ammo_holder__id) // in itemConteiner
  // check ammo already loaded
  interactable_invoice__available ||= ammo_loaded(interactable_invoice__hero, ammo_holder__id)
  // check have died teammates
  query(interactable_invoice__hero) <| $ [es] (team aka hero_team : int)
    interactable_invoice__available &&= find_query() <| $ [es] (team aka mate_team : int; eid, possessed : EntityId)
      if mate_team == hero_team && interactable_invoice__hero != eid
        return !(possessed |> get_bool("isAlive") ?? false)
      return false


[es(tag=server, no_order, REQUIRE=gravity_ammo__selectAction)]
def update_gravity_invoice_availability(info : ParallelUpdateFrameDelayed;
                                        interactable_invoice__hero : EntityId;
                                        ammo_holder__id : int;
                                        var interactable_invoice__available : bool&)
  interactable_invoice__available = has_holder(interactable_invoice__hero, ammo_holder__id)
  interactable_invoice__available &&= !ammo_loaded(interactable_invoice__hero, ammo_holder__id)
