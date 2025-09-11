from "%sqstd/string.nut" import tostring_r

from "weaponevents" import CmdTrackHeroWeapons
from "dagor.math" import Point2
from "humaninv" import INVALID_ITEM_ID
from "%ui/profile/profile_functions.nut" import getTemplateComponent
from "das.inventory" import get_current_move_mod_for_weapon, is_move_mod_from_weapon
from "%ui/hud/state/item_info.nut" import get_item_info, getSlotAvailableMods
from "%ui/hud/state/gametype_state.nut" import isOnPlayerBase
from "%ui/squad/squadState.nut" import isInSquad
from "dagor.debug" import logerr

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *






























const EES_HOLSTERING = 1
const EES_EQUIPING = 2


let weaponSlots = require("%ui/types/weapon_slots.nut")
let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")

let weaponsList = Watched([])  
let squadWeaponsList = Watched([])
let curWeapon = Watched(null)

let weaponSlotNames = ["primary", "secondary", "tertiary", "melee"]

let updateWeaponsList = @(list) weaponsList.set(list)
weaponsList.whiteListMutatorClosure(updateWeaponsList)

let updateSquadWeaponsList = @(list) squadWeaponsList.set(list)
squadWeaponsList.whiteListMutatorClosure(updateSquadWeaponsList)

console_register_command(function() {
                            if (weaponsList.get() != null) {
                              foreach (w in weaponsList.get()) {
                                vlog(tostring_r(w))
                              }
                            }
                          },
                          "hud.logWeaponList"
                        )


let itemIconQuery = ecs.SqQuery("itemIconQuery", {
  comps_ro = [
    ["animchar__res", ecs.TYPE_STRING, ""],
    ["item__iconYaw", ecs.TYPE_FLOAT, 0.0],
    ["item__iconPitch", ecs.TYPE_FLOAT, 0.0],
    ["item__iconRoll", ecs.TYPE_FLOAT, 0.0],
    ["item__iconOffset", ecs.TYPE_POINT2, Point2(0.0, 0.0)],
    ["item__iconScale", ecs.TYPE_FLOAT, 1.0],
    ["item__iconRecalcAnimation", ecs.TYPE_BOOL, false],
    ["weapon__iconYaw", ecs.TYPE_FLOAT, null],
    ["weapon__iconPitch", ecs.TYPE_FLOAT, null],
    ["weapon__iconRoll", ecs.TYPE_FLOAT, null],
    ["weapon__iconOffset", ecs.TYPE_POINT2, null],
    ["weapon__iconScale", ecs.TYPE_FLOAT, null],
    ["weapon__iconRecalcAnimation", ecs.TYPE_BOOL, null],
  ]
})

function setIconParams(itemEid, dst) {
  itemIconQuery.perform(itemEid, function (_eid, comp) {
    dst.__update({
      iconName = comp.animchar__res
      iconYaw = comp.weapon__iconYaw ?? comp.item__iconYaw
      iconPitch = comp.weapon__iconPitch ?? comp.item__iconPitch
      iconRoll = comp.weapon__iconRoll ?? comp.item__iconRoll
      iconOffsX = comp.weapon__iconOffset?.x ?? comp.item__iconOffset.x
      iconOffsY = comp.weapon__iconOffset?.y ?? comp.item__iconOffset.y
      iconScale = comp.weapon__iconScale ?? comp.item__iconScale
      iconRecalcAnimation = comp.weapon__iconRecalcAnimation ?? comp.item__iconRecalcAnimation
      lightZenith = 0
      lightAzimuth = 200
    })
  })
}

function setIconParamsByTemplate(itemTempl, dst) {
  if (itemTempl == null || itemTempl.len() == 0)
    return
  let templ = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemTempl)
  if (templ == null)
    return
  let iconOffset = templ.getCompValNullable("item__iconOffset") ?? Point2(0.0, 0.0)
  dst.__update({
    iconName = templ.getCompValNullable("animchar__res") ?? ""
    iconYaw = templ.getCompValNullable("item__iconYaw") ?? 0.0
    iconPitch = templ.getCompValNullable("item__iconPitch") ?? 0.0
    iconRoll = templ.getCompValNullable("item__iconRoll") ?? 0.0
    iconRecalcAnimation = templ.getCompValNullable("item__iconRecalcAnimation") ?? false
    iconOffsX = iconOffset.x
    iconOffsY = iconOffset.y
    iconScale = templ.getCompValNullable("item__iconScale") ?? 1.0
  })
}

let gunQuery = ecs.SqQuery("gunQuery", {
  comps_ro = [
    ["uniqueId", ecs.TYPE_STRING, "0"],
    ["gun__propsId", ecs.TYPE_INT, -1],
    ["gun__maxAmmo", ecs.TYPE_INT, 0],
    ["ammo_holder__ammoCountKnown", ecs.TYPE_EID_LIST, null],
    ["gun__ammo", ecs.TYPE_INT, 0],
    ["gun__owner", ecs.TYPE_EID, null],
    ["gun__isReloading", ecs.TYPE_BOOL, false],
    ["gun__disableAmmoUnload", ecs.TYPE_TAG, null],
    ["gun__boxedAmmoHolderTemplate", ecs.TYPE_STRING, ""],
    ["gun__ammoHolderIds", ecs.TYPE_INT_LIST, null],
    ["gun__firingModeName", ecs.TYPE_STRING, ""],
    ["gun__reloadable", ecs.TYPE_BOOL, false],
    ["gun_mods__slots", ecs.TYPE_SHARED_OBJECT, null],
    ["gun_mods__curModInSlots", ecs.TYPE_OBJECT, null],
    ["gun_boxed_ammo_reload__reloadState", ecs.TYPE_INT, null],
    ["item__name", ecs.TYPE_STRING, ""],
    ["item__weaponSlots", ecs.TYPE_STRING_LIST, null],
    ["item__id", ecs.TYPE_INT, INVALID_ITEM_ID],
    ["item__weapType", ecs.TYPE_STRING, null],
    ["grenade_thrower__projectileEntity", ecs.TYPE_EID, null],
    ["weapon_mods__delayedMoveSlotName", ecs.TYPE_STRING, null],
    ["default_stub_item", ecs.TYPE_TAG, null],
    ["gun_jamming__isJammed", ecs.TYPE_BOOL, false]
  ]
})
let weapon_proto = {
  uniqueId = 0
  isReloadable = false
  isCurrent = false
  isHolstering = false
  isEquiping = false
  isWeapon = false
  name = ""
  curAmmo = 0
  maxAmmo = 0
}

let modQuery = ecs.SqQuery("modQuery", {
  comps_ro = [
    ["uniqueId", ecs.TYPE_STRING, "0"],
    ["item__id", ecs.TYPE_INT, 0],
    ["item__name", ecs.TYPE_STRING, ""],
    ["item__proto", ecs.TYPE_STRING, ""],
    ["gunAttachable__slotName", ecs.TYPE_STRING, ""],
    ["item_holder__boxedItemTemplate", ecs.TYPE_STRING, null],
    ["gun__ammo", ecs.TYPE_INT, 0],
    ["item__weight", ecs.TYPE_FLOAT, 0],
    ["gun", null, null],
    ["item_holder_in_weapon_load", ecs.TYPE_TAG, null]
  ]
})

let mod_proto = {
  eid = 0
  uniqueId = 0
  itemPropsId = INVALID_ITEM_ID
  attachedItemName = ""
  attachedItemModSlotName = ""
  itemTemplate = ""
  isActivated = false
  isWeapon = false
  weapUniqueId = "0"
}

function getWeaponSlotAvailableGun(slotTemplateName) {
  let weaponSlotTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(slotTemplateName)
  if (weaponSlotTemplate == null) {
    logerr($"Invalid weapon_slot_template_name={weaponSlotTemplate}!")
    return []
  }
  return weaponSlotTemplate.getCompValNullable("slot_holder__availableItems")?.getAll() ?? []
}

function trackHeroWeapons(_evt, _eid, comp) {
  let isChanging = comp["human_net_phys__weapEquipCurState"] == EES_HOLSTERING ||
                     comp["human_net_phys__weapEquipCurState"] == EES_EQUIPING

  let weaponDescs = []
  let squadWeaponDescs = []
  weaponDescs.resize(weaponSlotNames.len(), null)
  squadWeaponDescs.resize(weaponSlotNames.len(), null)
  for (local j = 0; j < weaponSlotNames.len(); ++j) {
    let i = weaponSlots.weaponSlotsKeys.findindex(@(v) v==weaponSlotNames[j])
    if (i == null)
      continue
    local validWeaponSlots = null
    local itemId = null
    local gunMods = null
    local currentGunMods = null
    let mainGunEid = comp["human_weap__gunEids"][i]
    let currentGunEid = mainGunEid
    local grenadeEid = ecs.INVALID_ENTITY_ID
    gunQuery.perform(mainGunEid, function (__eid, gunComp) {
      validWeaponSlots = gunComp["item__weaponSlots"]?.getAll() ?? []
      itemId = gunComp["item__id"]
      gunMods = gunComp["gun_mods__slots"]?.getAll() ?? {}
      currentGunMods = gunComp["gun_mods__curModInSlots"]?.getAll() ?? {}
      grenadeEid = gunComp["grenade_thrower__projectileEntity"] ?? ecs.INVALID_ENTITY_ID
    })
    let desc = gunQuery.perform(currentGunEid, function (__eid, gunComp) {
      let isCurrentSlot = i == comp["human_weap__currentGunSlot"]
      let isReloadable = gunComp["gun__propsId"] >= 0 && i != weaponSlots.EWS_GRENADE ? gunComp["gun__reloadable"] : false

      local weaponDesc = ((i != weaponSlots.EWS_GRENADE) ? get_item_info(currentGunEid)
                                                         : get_item_info(grenadeEid)) ?? {}
      let weapUniqueId = gunComp["uniqueId"]
      weaponDesc.__update({
        uniqueId = weapUniqueId
        name = gunComp["item__name"]
        curAmmoCountKnown = gunComp["ammo_holder__ammoCountKnown"]?.getAll()?.contains(watchedHeroEid.get()) ?? true
        curAmmo = gunComp["gun__ammo"]
        maxAmmo = gunComp["gun__maxAmmo"]
        owner = gunComp["gun__owner"]
        itemPropsId = itemId
        firingMode = gunComp["gun__firingModeName"]
        isReloadable = isReloadable
        isUnloadable = gunComp["gun__disableAmmoUnload"] == null
        isReloading = gunComp["gun__isReloading"]
        isCurrent = isCurrentSlot
        isHolstering = isChanging && isCurrentSlot
        isEquiping = isChanging && comp["human_net_phys__weapEquipNextSlot"] == i
        isWeapon = validWeaponSlots.len() > 0
        isDefaultStubItem = gunComp["default_stub_item"] != null
        validWeaponSlots = validWeaponSlots
        grenadeType = null
        weapType = gunComp["item__weapType"]
        mods = {}
        ammoHolders = []
        isJammed = gunComp.gun_jamming__isJammed
      })

      weaponDesc.__update({
        usesBoxedAmmo = gunComp.gun_boxed_ammo_reload__reloadState != null
      })

      if (isReloadable) {
        weaponDesc.ammo <- {
          template = gunComp["gun__boxedAmmoHolderTemplate"]
          itemPropsId = getTemplateComponent(gunComp["gun__boxedAmmoHolderTemplate"], "ammo_holder__id") ?? 0
          name = getTemplateComponent(gunComp["gun__boxedAmmoHolderTemplate"], "item__name") ?? ""
        }
        if (weaponDesc.usesBoxedAmmo) {
          if (gunComp["gun__ammo"] > 0)
            setIconParamsByTemplate(gunComp["gun__boxedAmmoHolderTemplate"], weaponDesc.ammo)
          else
            weaponDesc.ammo.iconImage <- "ui/uiskin/rifle.svg"
          weaponDesc.ammoHolders = gunComp["gun__ammoHolderIds"]?.getAll() ?? []
        }
      }

      setIconParams(mainGunEid, weaponDesc)

      let curMoveEid = get_current_move_mod_for_weapon(currentGunEid)
      if (gunComp["weapon_mods__delayedMoveSlotName"] != null)
        currentGunMods[gunComp["weapon_mods__delayedMoveSlotName"]] <- curMoveEid
      if (gunMods != null) {
        foreach (slot, slotTemplateName in gunMods) {
          let slotTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(slotTemplateName)

          let modEid = currentGunMods?[slot] ?? ecs.INVALID_ENTITY_ID
          local modProps = mod_proto.__merge({
            parentWeaponName = weaponDesc?.name
            weapUniqueId
            slotTemplateName
            weapModSlotName = slot
            allowed_items = getSlotAvailableMods(slotTemplateName)
            isActivated = currentGunEid != mainGunEid
          })
          modProps.lockedInRaid <- slotTemplate?.hasComponent("mod_slot__lockedInRaid") ?? false
          if (modEid == ecs.INVALID_ENTITY_ID) {
            modProps.defaultIcon <- slotTemplate?.getCompValNullable("mod_slot__icon") ?? ""
            modProps.slotTooltip <- slotTemplate?.getCompValNullable("mod_slot__tooltip") ?? ""
          }
          local modTempl = ""
          let info = get_item_info(modEid)
          if (info != null)
            modProps = modProps.__update(info)

          modQuery.perform(modEid, function (___eid, modComp) {
            local additionalWeight = 0.0
            let isLoadingAmmo = modComp["item_holder_in_weapon_load"] != null
            let isDelayedMoveMod = (modEid == curMoveEid) && !isLoadingAmmo
            let boxedTemplateName = modComp?["item_holder__boxedItemTemplate"]
            if (boxedTemplateName) {
              let boxedTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(boxedTemplateName)
              let weightPerStack = boxedTemplate?.getCompValNullable("item__weightPerStack") ?? 0
              let countPerStack = boxedTemplate?.getCompValNullable("item__countPerStack") ?? 1

              
              let currentAmmo = max((weaponDesc?.curAmmo ?? 0) - 1, 0)

              additionalWeight = weightPerStack / countPerStack * currentAmmo
            }

            modProps.__update({
              eid = modEid
              uniqueId = modComp["uniqueId"]
              itemPropsId = modComp["item__id"]
              attachedItemName = modComp["item__name"] ?? ""
              attachedItemModSlotName = modComp["gunAttachable__slotName"] ?? ""
              itemTemplate = modComp["item__proto"] ?? ""
              isWeapon = modComp["gun"] != null
              weight = modComp["item__weight"] + additionalWeight
              isLoadingAmmo = isLoadingAmmo
              isDelayedMoveMod = isDelayedMoveMod
              inactiveItem = !isDelayedMoveMod || is_move_mod_from_weapon(modEid)
            })
            modTempl = modComp["item__proto"]
          })
          weaponDesc.mods[slot] <- modProps
          setIconParamsByTemplate(modTempl, weaponDesc.mods[slot])
        }
      }
      return weaponDesc
    })
    weaponDescs[i] = (desc == null) ? clone weapon_proto : desc
    weaponDescs[i].weaponSlotKey <- weaponSlots.weaponSlotsKeys[i]
    weaponDescs[i].currentWeaponSlotName <- weaponSlotNames[i]
    let slotHolderTemplateName = comp.slots_holder__slotTemplates[weaponSlots.weaponSlotsKeys[i]]
    weaponDescs[i].__update({allowed_items = getWeaponSlotAvailableGun(slotHolderTemplateName)})
    squadWeaponDescs[i] = {
      itemTemplate = weaponDescs?[i].itemTemplate
      isCurrent = weaponDescs?[i].isCurrent
      name = weaponDescs?[i].name
      currentWeaponSlotName = weaponDescs?[i].currentWeaponSlotName
      mods = weaponDescs?[i].mods.map(@(v) {
        itemTemplate = v?.itemTemplate
        slotTemplateName = v?.slotTemplateName
        attachedItemModSlotName = v?.attachedItemModSlotName
      }) ?? {}
    }
    if (weaponDescs?[i].weaponSlotKey != null)
      squadWeaponDescs[i].__update({ weaponSlotKey = weaponDescs?[i].weaponSlotKey })
  }

  updateWeaponsList(weaponDescs)
  updateSquadWeaponsList(squadWeaponDescs)
  if (type(weaponDescs) != "array" || weaponDescs.len() == 0)
    return
  let weapon = weaponDescs.findvalue(@(w) w.isCurrent)
  if (weapon == null)
    return
  curWeapon.set(weapon)
}

ecs.register_es("hero_state_weapons_ui_es",
  {
    [["onInit", ecs.EventComponentChanged,"onDestroy", CmdTrackHeroWeapons]] = trackHeroWeapons,
  },
  {
    comps_rq = ["watchedByPlr"]
    comps_track = [
      ["human_weap__gunEids", ecs.TYPE_EID_LIST],
      ["human_weap__currentGunSlot", ecs.TYPE_INT],
      ["human_net_phys__weapEquipCurState", ecs.TYPE_INT],
      ["human_net_phys__weapEquipNextSlot", ecs.TYPE_INT],
      ["itemContainer", ecs.TYPE_EID_LIST],
      ["slots_holder__slotTemplates", ecs.TYPE_SHARED_OBJECT]
    ]
  }
)

ecs.register_es("hero_state_weapons_ui_by_weapon_es",
  {
    [["onChange"]] = @(_evt, _eid, _comps) ecs.g_entity_mgr.sendEvent(watchedHeroEid.get(), CmdTrackHeroWeapons())
  },
  {
    comps_rq = ["watchedPlayerItem", "gun"]
    comps_track = [
      ["gun_mods__curModInSlots", ecs.TYPE_OBJECT, null],
      ["weapon_mods__modDelayedUnequipEid", ecs.TYPE_EID, null],
      ["weapon_mods__modDelayedEquipEid", ecs.TYPE_EID, null],
      ["ammo_holder__ammoCountKnown", ecs.TYPE_EID_LIST, null],
      ["gun_jamming__isJammed", ecs.TYPE_BOOL, false]
  ]
  }
)

ecs.register_es("hero_state_weapons_update_loading_magazine",
  {
    [["onChange"]] = @(_evt, _eid, _comp) ecs.g_entity_mgr.sendEvent(watchedHeroEid.get(), CmdTrackHeroWeapons())
  },
  {
    comps_rq = [["watchedPlayerItem"], ["item_holder_in_weapon_load"]]
    comps_track = [["item__currentBoxedItemCount", ecs.TYPE_INT],
                   ["ammo_holder__ammoCountKnown", ecs.TYPE_EID_LIST, null]]
  }
)



ecs.register_es("hero_state_mod_ui_es",
  {
    [["onChange", "onInit"]] = @(_evt, _eid, _comp) ecs.g_entity_mgr.sendEvent(watchedHeroEid.get(), CmdTrackHeroWeapons())
  },
  {
    comps_rq = [
      ["watchedPlayerItem"],
      ["weaponMod"]
    ]
    comps_track = [
      ["ammo_holder__ammoCountKnown", ecs.TYPE_EID_LIST, null]
    ]
  }
)

function trackWeapon(_evt, _eid, comp) {
  let hero = watchedHeroEid.get()
  if (comp["gun__owner"] == hero)
    ecs.g_entity_mgr.sendEvent(hero, CmdTrackHeroWeapons())
}

ecs.register_es("hero_state_melee_workaround_ui_es",
  {
    onInit = trackWeapon
  },
  {
    comps_ro = [["gun__owner", ecs.TYPE_EID]]
    comps_rq = [["gun__melee", ecs.TYPE_BOOL]]
  }
)

ecs.register_es("hero_state_gun_workaround_ui_es",
  {
    [["onInit", "onChange","onDestroy"]] = trackWeapon,
  },
  {
    comps_rq = ["gun"]
    comps_track = [
      ["gun__owner", ecs.TYPE_EID],
      ["gun__firingModeIndex", ecs.TYPE_INT],
      ["gun__ammo", ecs.TYPE_INT],
      ["gun__isReloading", ecs.TYPE_BOOL]
    ]
  }
)

return {
  weaponsList
  squadWeaponsList
  curWeapon
  weaponSlotNames
}
