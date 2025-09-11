from "%ui/hud/menus/components/inventoryCommon.nut" import mkInventoryHeader
from "%ui/hud/menus/components/inventoryItemsList.nut" import itemsPanelList, setupPanelsData, inventoryItemSorting
from "%ui/hud/menus/components/inventoryItemUtils.nut" import mergeNonUniqueItems
from "%ui/hud/menus/components/inventoryVolumeWidget.nut" import mkVolumeHdr
from "das.inventory" import calc_stacked_item_volume
from "%ui/hud/menus/components/fakeItem.nut" import mkFakeItem
from "%ui/hud/menus/components/inventoryItemsListChecksCommon.nut" import MoveForbidReason
from "string" import startswith

import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { previewPreset, previewPresetCallbackOverride } = require("%ui/equipPresets/presetsState.nut")
let { defaultVolume } = require("%ui/hud/state/inventory_common_es.nut")
let { HERO_ITEM_CONTAINER, BACKPACK0, SAFEPACK } = require("%ui/hud/menus/components/inventoryItemTypes.nut")


function fakeItemAsAttaches(suitTemplateName, bodyTypeId, slotKey=null, unhideNodes=[]) {
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(suitTemplateName)

  let reverseViewLogic = template?.getCompValNullable("slot_attach__attached_show_dynmodel_nodes__forceShownNodes") != null
  if (reverseViewLogic) {
    return []
  }

  local hideNodes = (template?.getCompValNullable("animchar_dynmodel_nodes_hider__hiddenNodes")?.getAll() ?? [])
  hideNodes = hideNodes.filter(function(hidden) {
    return unhideNodes.findindex(@(unhideIdx) hidden == unhideIdx) == null
  })

  let stubs = (template?.getCompValNullable("equipment__setDefaultStubEquipmentTemplates").getAll() ?? {}).map(function(v) {
    return v.split("+")[0]
  })
  let attachableAnimchar = stubs.__update(template?.getCompValNullable("suit_attachable_item__animcharTemplates").getAll() ?? {})

  let ret = []

  if (attachableAnimchar?.len()) {
    foreach (animKey, animTemplate in attachableAnimchar) {
      let templ = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(animTemplate)
      let attachTemplateName = templ?.getCompValNullable("sex_based_subattach_controller__animcharTemplates").getAll()[bodyTypeId] ?? animTemplate
      let attachTempl = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(attachTemplateName)
      let animchar = attachTempl?.getCompValNullable("animchar__res")
      let isSkeleton = attachTempl?.hasComponent("skeleton_attach__attached") ?? false

      if (animchar == null)
        continue

      ret.append({
        slotName = isSkeleton ? null : animKey
        animchar
        hideNodes = []
      })
    }
  }
  else {
    let attachTemplateName = template?.getCompValNullable("sex_based_subattach_controller__animcharTemplates").getAll()[bodyTypeId] ?? suitTemplateName
    let attachTempl = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(attachTemplateName)
    let animchar = attachTempl?.getCompValNullable("animchar__res")
    let isSkeleton = attachTempl?.hasComponent("skeleton_attach__attached") ?? false

    if (animchar) {
      ret.append({
        slotName = isSkeleton ? null : slotKey
        animchar = animchar
        hideNodes
      })
    }
  }

  return ret
}

function fakeEquipmentAsAttaches(equipment) {
  let unhide = []
  local bodyTypeId = 0
  let suit = equipment?["chronogene_primary_1"]

  if (suit?.itemTemplate == null)
    return []

  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(suit.itemTemplate)
  bodyTypeId = template?.getCompValNullable("suit__suitType") ?? 0

  foreach (item in equipment) {
    if (item?.itemTemplate == null)
      continue
    let itemTemplate = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(item.itemTemplate)

    let curUnhide = itemTemplate?.getCompValNullable("slot_attach__attached_show_dynmodel_nodes__forceShownNodes")?.getAll() ?? []

    unhide.extend(curUnhide)
  }

  let ret = []

  foreach (slotKey, slotItem in equipment) {
    if (
        slotItem?.itemTemplate == null ||
        startswith(slotKey, "chronogene_secondary") || 
        slotKey == "chronogene_primary_1" 
      )
        continue

    let attaches = fakeItemAsAttaches(slotItem.itemTemplate, bodyTypeId, slotKey, unhide)

    foreach (newAtt in attaches) {
      if (newAtt.slotName) {
        let alreadyExists = ret.findindex(@(v) v.slotName == newAtt.slotName) != null
        if (alreadyExists)
          continue
      }
      ret.append(newAtt)
    }
  }

  let attaches = fakeItemAsAttaches(equipment["chronogene_primary_1"].itemTemplate, bodyTypeId, "chronogene_primary_1", unhide)
  foreach (newAtt in attaches) {
    if (newAtt.slotName) {
      let alreadyExists = ret.findindex(@(v) v.slotName == newAtt.slotName) != null
      if (alreadyExists)
        continue
    }
    ret.append(newAtt)
  }

  return ret
}

const itemsInRow = 3
let processItems = @(v) v

let inventoryBlocksPanelsData = {}
let getInventoryBlockData = function(inventoryBlockName) {
  if (inventoryBlockName not in inventoryBlocksPanelsData) {
    let fakeItemsWatched = Watched([])
    let panelsData = setupPanelsData(fakeItemsWatched,
                                      itemsInRow,
                                      [fakeItemsWatched],
                                      processItems)
    inventoryBlocksPanelsData[inventoryBlockName] <- {
      panelsData
      fakeItemsWatched
    }
  }

  return inventoryBlocksPanelsData[inventoryBlockName]
}

function getItemVolume(item) {
  return item.isBoxedItem ?
    calc_stacked_item_volume(item.countPerStack, item?.ammoCount ?? 0, item.volumePerStack) :
    item.volume
}

function mkInventoryPresetPreview(inventoryBlockName, list_type, actions = null, visualYSize = null, capacityWatch = Watched(0)) {
  let {panelsData, fakeItemsWatched} = getInventoryBlockData(inventoryBlockName)

  return function() {
    panelsData.resetScrollHandlerData()
    let presetData = previewPreset.get()
    let presetInventoryItems = presetData?["inventories"][inventoryBlockName].items ?? []

    local fakeItems = presetInventoryItems.map(@(item)
      mkFakeItem(item.itemTemplate,
        item.__merge( {
          charges = item?.charges
          ammoCount = item?.ammoCount ?? item?.charges
          noSuitableItemForPresetFoundCount = item?.noSuitableItemForPresetFoundCount
        })
      )
    )
    local volume = 0.0
    fakeItems.each(function(item) {
      volume += getItemVolume(item)
    })
    let totalVolume = Watched(volume)
    fakeItems = mergeNonUniqueItems(fakeItems)

    fakeItems.sort(inventoryItemSorting)
    fakeItemsWatched.set(fakeItems)

    let inventoryActions = previewPresetCallbackOverride.get()?["inventories"][inventoryBlockName]
    let can_drop_dragged_cb = inventoryActions?.can_drop_dragged_cb ?? function(item) {
      if (item?.fromList.name == list_type.name)
        return MoveForbidReason.OTHER
      let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(item.itemTemplate)
      local itemVol = 0
      if (item.isBoxedItem) {
        
        itemVol = template.getCompValNullable("item__volumePerStack") ?? 0
      }
      else {
        itemVol = template.getCompValNullable("item__volume") ?? 0
      }
      if (itemVol + totalVolume.get() >= capacityWatch.get()) {
        return MoveForbidReason.VOLUME
      }
      return MoveForbidReason.NONE
    }
    let on_item_dropped_to_list_cb = inventoryActions?.on_item_dropped_to_list_cb

    let children = itemsPanelList({
      outScrollHandlerInfo=panelsData.scrollHandlerData,
      list_type,
      item_actions = actions ?? {}
      itemsPanelData=panelsData.itemsPanelData,
      headers=mkInventoryHeader(
        loc($"inventory/{inventoryBlockName}")
        mkVolumeHdr(totalVolume, capacityWatch, "inventory")
      )
      ySize = visualYSize

      can_drop_dragged_cb
      on_item_dropped_to_list_cb
    })

    return {
      watch = [ panelsData.numberOfPanels, previewPreset, previewPresetCallbackOverride]
      size = FLEX_V
      children,
      
      
      onAttach = @() panelsData.onAttach(),
      onDetach = @() panelsData.onDetach()
    }
  }
}

function mkHeroInventoryPresetPreview(actions=null, visualYSize = null) {
  let capacity = Computed(function() {
    local cap = defaultVolume.get()
    let itemTemplate = previewPreset.get()?.pouch.itemTemplate
    if (itemTemplate) {
      let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemTemplate)
      cap += template?.getCompValNullable("item__inventoryExtension") ?? 0
    }

    return cap
  })
  return mkInventoryPresetPreview("myItems", HERO_ITEM_CONTAINER, actions, visualYSize, capacity)
}

function inventoryCapacity(inventoryName, preset) {
  let itemTemplate = preset?[inventoryName].itemTemplate
  if (itemTemplate == null)
    return 0
  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemTemplate)
  let cap = template?.getCompValNullable("human_inventory__maxVolume") ?? 0

  return cap
}

function mkInventoryCapacityComputed(inventoryName) {
  return Computed(function() {
    return inventoryCapacity(inventoryName, previewPreset.get())
  })
}

function mkBackpackInventoryPresetPreview(actions=null, visualYSize = null) {
  let capacity = mkInventoryCapacityComputed("backpack")
  return mkInventoryPresetPreview("backpack", BACKPACK0, actions, visualYSize, capacity)
}

function mkSafepackInventoryPresetPreview(actions=null, visualYSize = null) {
  let capacity = mkInventoryCapacityComputed("safepack")
  return mkInventoryPresetPreview("safepack", SAFEPACK, actions, visualYSize, capacity)
}


return {
  mkInventoryPresetPreview
  fakeEquipmentAsAttaches
  fakeItemAsAttaches
  mkHeroInventoryPresetPreview
  mkBackpackInventoryPresetPreview
  mkSafepackInventoryPresetPreview
  inventoryCapacity
  getItemVolume
}