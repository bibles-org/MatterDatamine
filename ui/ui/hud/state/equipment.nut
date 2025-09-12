from "%ui/hud/state/item_info.nut" import get_item_info, getSlotAvailableMods
from "%ui/hud/menus/components/itemFromTemplate.nut" import getSlotFromTemplate
from "%ui/helpers/common_queries.nut" import get_animchar_attach__attachedTo
from "gameevents" import EventHeroChanged

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { watchedHeroEid } = require("%ui/hud/state/watched_hero.nut")

let equipment = Watched({})
let attachedEquipment = Watched({})
let hasFlashlight = Watched(false)

let equipmentModSlots = Watched({})


let equipmentModsQuery = ecs.SqQuery("equipmentModsQuery",
{
  comps_ro=[
    ["equipment_mods__slots", ecs.TYPE_SHARED_OBJECT],
    ["equipment_mods__curModInSlots", ecs.TYPE_OBJECT],
  ]
})

function getSlotData(parentEid, itemEid, slotTemplateName, slotName, parentSlotName=null) {
  let itemInfo = itemEid != ecs.INVALID_ENTITY_ID ? get_item_info(itemEid) : {}
  let item = itemInfo ?? {}
  let slot = getSlotFromTemplate(slotTemplateName, {}, parentSlotName ? parentEid : itemEid)
  return {
    attachedToEquipment = parentEid
    iconImageColor = Color(101, 101, 101, 51)
    slotName
  }.__update(
    item,
    slot,
    parentSlotName ? { parentSlotName } : {}
  )
}

function getEquipmentModSlots(equipmentItem) {
  let equipmentComp = equipmentModsQuery.perform(equipmentItem.eid, @(_eid, comp) comp)

  let slots = equipmentComp?.equipment_mods__slots?.getAll() ?? {}
  let curModInSlots = equipmentComp?.equipment_mods__curModInSlots ?? {}
  let parentSlotName = equipmentItem?.slotName

  let ret = slots.map(function(slotTemplateName, slotName){
    let modEid = curModInSlots?[slotName] ?? ecs.INVALID_ENTITY_ID
    return getSlotData(equipmentItem.eid, modEid, slotTemplateName, slotName, parentSlotName)
  })
  return ret
}

function update_equipment_mod_slots() {
  local modSlots = {}
  foreach (equipmentSlot, equipmentValue in equipment.get()) {
    let equipmentEid = equipmentValue?.eid ?? ecs.INVALID_ENTITY_ID
    if (equipmentEid != ecs.INVALID_ENTITY_ID) {
      modSlots[equipmentSlot] <- getEquipmentModSlots(equipmentValue)
    }
  }
  equipmentModSlots.set(modSlots)
}

equipment.subscribe_with_nasty_disregard_of_frp_update(function(v) {
  let flashlightEid = v?["flashlight"]?.eid
  hasFlashlight.set(flashlightEid != null && flashlightEid != ecs.INVALID_ENTITY_ID)

  update_equipment_mod_slots()
})

ecs.register_es("hero_equipment_mod_hp_track_ui_es", {
  [["onChange"]] = function(_evt, _eid, _comp) {
    update_equipment_mod_slots()
  }
},
{
  comps_ro = [
    ["animchar_attach__attachedTo", ecs.TYPE_EID]
  ],
  comps_track = [
    ["item__hp", ecs.TYPE_FLOAT, 0.0],
    ["item__amount", ecs.TYPE_INT, 0],
    ["item__currentBoxedItemCount", ecs.TYPE_INT, 0],
    ["equipmentAttachable__slotName", ecs.TYPE_STRING]
  ],
  comps_rq = [
    ["equipment_mod_item", ecs.TYPE_TAG],
    ["watchedPlayerItem", ecs.TYPE_TAG]
  ]
})

function isEquipmentHasSlot(equipment_eid, slot_name) {
  let equipmentComp = equipmentModsQuery.perform(equipment_eid, @(_eid, comp) comp)
  let slots = equipmentComp?.equipment_mods__slots
  if (slots == null)
    return false

  return slots?[slot_name] != null
}

function isModForEquipmentSlot(mod_eid, equipment_eid, slot_name) {
  if (slot_name == null)
    return false
  let equipmentComp = equipmentModsQuery.perform(equipment_eid, @(_eid, comp) comp)
  let slots = equipmentComp?.equipment_mods__slots
  if (slots == null)
    return false

  let slotTemplateName = slots?[slot_name]
  if (slotTemplateName == null)
    return false

  let modTemplate = ecs.g_entity_mgr.getEntityTemplateName(mod_eid)
  if (modTemplate == null)
    return false

  let availableModTemplates = getSlotAvailableMods(slotTemplateName)
  foreach (availableModTemplate in availableModTemplates)
    if (modTemplate.contains(availableModTemplate))
      return true

  return false
}

let get_heroslots_info_query = ecs.SqQuery("get_heroslots_info_query", {
  comps_ro = [
    ["human_equipment__slots", ecs.TYPE_OBJECT],
    ["human_equipment__slotsFlags", ecs.TYPE_OBJECT],
    ["slots_holder__slotTemplates", ecs.TYPE_SHARED_OBJECT]
  ],
  comps_rq = ["watchedByPlr"]
})


function updateEquipment(eid, comp) {
  let slots = comp["human_equipment__slots"]
  let slotsFlags = comp["human_equipment__slotsFlags"]
  let slotsTemplates = comp["slots_holder__slotTemplates"]

  let res = {}
  if (slots != null) {
    foreach (slotName, itemInSlot in slots) {
      res[slotName] <- getSlotData(eid, itemInSlot, slotsTemplates[slotName], slotName).__update({
        flags = slotsFlags?[slotName]
      })
    }
  }
  equipment.set(res)
}

ecs.register_es("hero_equipment_script_es", {
    [["onInit", EventHeroChanged, "onChange"]] = function(_evt, eid, comp) {
      updateEquipment(eid, comp)
    },
  },
  { comps_track = [
      ["human_equipment__slots", ecs.TYPE_OBJECT],
      ["human_equipment__slotsFlags", ecs.TYPE_OBJECT]
    ],
    comps_ro = [["slots_holder__slotTemplates", ecs.TYPE_SHARED_OBJECT]],
    comps_rq = ["watchedByPlr"]
  }
)

ecs.register_es("equipment_mods_track_cur_mod_in_slots_ui_es", {
  [["onChange"]] = function(_evt, _eid, _comp) {
    get_heroslots_info_query.perform(watchedHeroEid.get(), updateEquipment)
  }
},
{
  comps_track = [
    ["equipment_mods__curModInSlots", ecs.TYPE_OBJECT],
    ["watchedPlayerItem", ecs.TYPE_TAG]
  ]
})


ecs.register_es("hero_equipment_hp_track_ui_es", {
  [["onChange"]] = function(_evt, _eid, comp) {
    let heroEidV = watchedHeroEid.get()

    let attachedToEid = comp["animchar_attach__attachedTo"]
    let parentAttachedTo = get_animchar_attach__attachedTo(attachedToEid)

    if (attachedToEid == heroEidV || parentAttachedTo == heroEidV)
      get_heroslots_info_query.perform(heroEidV, updateEquipment)
  }
},
{
  comps_ro = [
    ["animchar_attach__attachedTo", ecs.TYPE_EID]
  ],
  comps_track = [
    ["item__hp", ecs.TYPE_FLOAT],
  ],
  comps_rq = [
    ["equipment_item", ecs.TYPE_TAG],
    ["watchedPlayerItem", ecs.TYPE_TAG]
  ]
})


ecs.register_es("hero_equipment_volume_track_ui_es", {
  [["onChange"]] = function(_evt, _eid, _comp) {
    get_heroslots_info_query.perform(watchedHeroEid.get(), updateEquipment)
  }
},
{
  comps_track = [
    ["item__volume", ecs.TYPE_INT],
  ],
  comps_rq = [
    ["equipment_item", ecs.TYPE_TAG],
    ["watchedPlayerItem", ecs.TYPE_TAG]
  ]
})

let addAttach = function(eid, comp) {
  let hideNodes = []
  if (comp.animchar_dynmodel_nodes_hider__hiddenNodes != null){
    let showNodes = comp.animchar_dynmodel_nodes_hider__forceShownNodes.getAll()
    hideNodes.extend(
      comp.animchar_dynmodel_nodes_hider__hiddenNodes.getAll().filter(@(i) !showNodes.contains(i))
    )
  }
  let entry = {
    animchar = comp.animchar__res
    slotName = comp.slot_attach__slotName
    objTexReplace = comp?.animchar__objTexReplace.getAll()
    itemProto = comp.item__proto
    equipmentSlot = comp?.equipable_item__curSlot
  }.__merge(hideNodes.len() > 0 ? { hideNodes } : {})
  attachedEquipment.mutate(@(t) t[eid] <- entry)
}

ecs.register_es("hero_attached_equipment_track_ui_es", {
  onInit = function(eid, comp){
    if (comp.item__invisible != null)
      return

    addAttach(eid, comp)
  }
  onChange = function(eid, comp) {
    if (comp.item__invisible != null)
      attachedEquipment.mutate(@(t) eid in t ? t.$rawdelete(eid) : null)
    if (comp.item__invisible == null && !(eid in attachedEquipment))
      addAttach(eid, comp)
    if (eid in attachedEquipment.get()) {
      attachedEquipment.mutate(function(t) {
        if (comp.animchar_dynmodel_nodes_hider__forceShownNodes != null) {
          let showNodes = comp.animchar_dynmodel_nodes_hider__forceShownNodes.getAll()
          if ("hideNodes" in t[eid])
            t[eid].hideNodes <- comp.animchar_dynmodel_nodes_hider__hiddenNodes.getAll()
              .filter(@(i) !showNodes.contains(i))
        }
        else {
          t[eid].slotName = comp.slot_attach__slotName
        }
      })
    }
  }
  onDestroy = function(eid, _comp) {
    attachedEquipment.mutate(@(t) eid in t ? t.$rawdelete(eid) : null)
  }
},
{
  comps_ro = [
    ["animchar__res", ecs.TYPE_STRING],
    ["item__invisible", ecs.TYPE_TAG, null],
    ["item__proto", ecs.TYPE_STRING, null],
    ["slot_attach__slotName", ecs.TYPE_STRING, null],
    ["animchar__objTexReplace", ecs.TYPE_OBJECT, null]
  ],
  comps_track = [
    ["animchar_dynmodel_nodes_hider__hiddenNodes", ecs.TYPE_STRING_LIST, null],
    ["animchar_dynmodel_nodes_hider__forceShownNodes", ecs.TYPE_STRING_LIST, null],
    ["slot_attach__slotId", ecs.TYPE_INT, null],
    ["equipable_item__curSlot", ecs.TYPE_STRING, null]
  ],
  comps_rq = ["watchedPlayerItem", "attachedToParent"],
  comps_no = ["suit_attachable_item_in_equipment", "gun", "gunAttachable", "gun__melee", "item_in_equipment_hided_on_doll"]
})

ecs.register_es("hero_integrated_suits_track_ui_es", {
  onInit = @(eid, comp) attachedEquipment.mutate(@(t) t[eid] <- {
    animchar = comp.animchar__res
    slotName = null
  })
  onDestroy = @(eid, _comp) attachedEquipment.mutate(@(t) eid in t ? t.$rawdelete(eid) : null)
},
{
  comps_ro = [["animchar__res", ecs.TYPE_STRING]],
  comps_rq = ["watchedByPlr", "integratedSuit"]
})

return {
  equipment
  attachedEquipment
  hasFlashlight
  equipmentModSlots
  isEquipmentHasSlot
  isModForEquipmentSlot
  getEquipmentModSlots
  getSlotData
}