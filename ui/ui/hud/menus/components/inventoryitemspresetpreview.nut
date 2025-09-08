import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let { mkInventoryHeader } = require("%ui/hud/menus/components/inventoryCommon.nut")
let { itemsPanelList, setupPanelsData, inventoryItemSorting } = require("%ui/hud/menus/components/inventoryItemsList.nut")
let { mergeNonUniqueItems } = require("%ui/hud/menus/components/inventoryItemUtils.nut")
let { previewPreset, previewPresetCallbackOverride } = require("%ui/equipPresets/presetsState.nut")
let { mkVolumeHdr } = require("%ui/hud/menus/components/inventoryVolumeWidget.nut")
let { calc_stacked_item_volume, convert_volume_to_int } = require("das.inventory")
let { mkFakeItem } = require("fakeItem.nut")
let { defaultMaxVolume } = require("%ui/hud/state/inventory_common_es.nut")
let { MoveForbidReason } = require("%ui/hud/menus/components/inventoryItemsListChecksCommon.nut")
let { startswith } = require("string")
let { HERO_ITEM_CONTAINER, BACKPACK0, SAFEPACK } = require("%ui/hud/menus/components/inventoryItemTypes.nut")

function fakeEquipmentAsAttaches(equipment) {
  let unhide = []
  local bodyTypeId = 0
  let suit = equipment?["chronogene_primary_1"]
  if (suit && suit?.itemTemplate) {
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(suit.itemTemplate)
    bodyTypeId = template?.getCompValNullable("suit__suitType") ?? 0
  }

  foreach (item in equipment) {
    if (item?.itemTemplate == null)
      continue
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(item.itemTemplate)

    let curUnhide = template?.getCompValNullable("slot_attach__attached_show_dynmodel_nodes__forceShownNodes")?.getAll() ?? []

    unhide.extend(curUnhide)
  }

  let ret = []

  foreach (slotKey, slotItem in equipment) {
    
    if (slotItem?.itemTemplate == null || startswith(slotKey, "chronogene_secondary"))
      continue
    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(slotItem.itemTemplate)

    let reverseViewLogic = template?.getCompValNullable("slot_attach__attached_show_dynmodel_nodes__forceShownNodes") != null
    if (reverseViewLogic) {
      continue
    }

    local hideNodes = (template?.getCompValNullable("animchar_dynmodel_nodes_hider__hiddenNodes")?.getAll() ?? [])
    hideNodes = hideNodes.filter(function(hidden) {
      return unhide.findindex(@(unhideIdx) hidden == unhideIdx) == null
    })

    let attachableAnimchar = template?.getCompValNullable("suit_attachable_item__animcharTemplates").getAll()

    if (attachableAnimchar?.len()) {
      foreach (_animKey, animTemplate in attachableAnimchar) {
        let templ = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(animTemplate)
        let attachTemplateName = templ?.getCompValNullable("suit_attachable_item__suitTypeBasedAnimcharTemplates").getAll()[bodyTypeId] ?? animTemplate
        let attachTempl = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(attachTemplateName)
        let animchar = attachTempl?.getCompValNullable("animchar__res")

        if (animchar == null)
          continue

        ret.append({
          slotName = null
          animchar
          hideNodes = []
        })
      }
    }
    else {
      let attachTemplateName = template?.getCompValNullable("suit_attachable_item__suitTypeBasedAnimcharTemplates").getAll()[bodyTypeId] ?? slotItem.itemTemplate
      let attachTempl = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(attachTemplateName)
      let animchar = attachTempl?.getCompValNullable("animchar__res")
      let isSkeleton = attachTempl?.getCompValNullable("skeleton_attach__attachedTo") != null

      if (animchar) {
        ret.append({
          slotName = isSkeleton ? null : slotKey
          animchar = animchar
          hideNodes
        })
      }
    }
  }

  return ret
}

const itemsInRow = 3
let processItems = @(v) v

let inventoryBlocksPanelsData = {}
let getInventoryBlockData = function(inventoryBlockName) {
  if (!(inventoryBlockName in inventoryBlocksPanelsData)) {
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
    convert_volume_to_int(item.volume)
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
    let totalVolume = Watched(volume /= 10)
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
      size = [ SIZE_TO_CONTENT, flex() ]
      children,
      
      
      onAttach = @() panelsData.onAttach(),
      onDetach = @() panelsData.onDetach()
    }
  }
}

function mkHeroInventoryPresetPreview(actions=null, visualYSize = null) {
  let capacity = Computed(function() {
    local cap = defaultMaxVolume.get() * 10
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
  mkHeroInventoryPresetPreview
  mkBackpackInventoryPresetPreview
  mkSafepackInventoryPresetPreview
  inventoryCapacity
  getItemVolume
}