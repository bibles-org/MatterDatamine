from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let { stashItems } = require("%ui/hud/state/inventory_items_es.nut")
let { itemsPanelList, setupPanelsData } = require("%ui/hud/menus/components/inventoryItemsList.nut")
let { mergeNonUniqueItems } = require("%ui/hud/menus/components/inventoryItemUtils.nut")
let { equipment } = require("%ui/hud/state/equipment.nut")
let { currentChronogenes, sendRawChronogenes } = require("cloneMenuState.nut")
let { GENES_SECONDARY } = require("%ui/hud/menus/components/inventoryItemTypes.nut")
let { panelParams, mkText } = require("%ui/components/commonComponents.nut")
let { MoveForbidReason } = require("%ui/hud/menus/components/inventoryItemsListChecksCommon.nut")
let { marketItems } = require("%ui/profile/profileState.nut")
let { mkFakeItem } = require("%ui/hud/menus/components/fakeItem.nut")

let selectedMainChronogeneItem = Watched(null)

function isItemCanBeDroppedInGenes(data, list_type) {
  if (list_type.name == "mainGenes")
    return MoveForbidReason.OTHER
  if (data?.profileGeneSlotList == null)
    return MoveForbidReason.OTHER

  if (data && data?.canDrop && data.filterType == "chronogene")
    return MoveForbidReason.NONE
  return MoveForbidReason.OTHER
}

function tryEquipGeneToContainer(listName, chronogene, wishIdx=-1) {
  if (chronogene?.forceLockIcon)
    return false
  let idx = wishIdx >= 0 ? wishIdx :
    listName == "primaryChronogenes" ?
    0 : 
    currentChronogenes.get()[listName].findindex(@(v) v.tostring() == "0")
  if (idx == null)
    return false

  let newContainer = clone(currentChronogenes.get())
  newContainer[listName][idx] = chronogene.uniqueId
  sendRawChronogenes(newContainer)
  return true
}

function equipChronogene(chronogene) {
  foreach (slot in (chronogene.equipmentSlots ?? [])) {
    if(slot.contains("chronogene_primary")) {
      if(tryEquipGeneToContainer("primaryChronogenes", chronogene))
        return
    }
    else if(slot.contains("chronogene_secondary")) {
      if(tryEquipGeneToContainer("secondaryChronogenes", chronogene))
        return
    }
  }
}

function unequipChronogene(chronogene) {
  let secondaryChronogeneIdx = currentChronogenes.get()?.secondaryChronogenes.findindex(@(v) v == chronogene.uniqueId)
  if (secondaryChronogeneIdx != null) {
    let newContainer = clone(currentChronogenes.get())
    newContainer.secondaryChronogenes[secondaryChronogeneIdx] = "0"
    sendRawChronogenes(newContainer)
  }
}

let allChronogenesInGame = Computed(@() marketItems.get().values()?.map(function(i){
    let itemTemplate = i.children?.items[0]?.templateName
    if (itemTemplate == null)
      throw null
    let templ = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemTemplate)
    let filterName = templ?.getCompValNullable("item__filterType")
    let sortingPriority = templ?.getCompValNullable("item__uiSortingPriority") ?? 0
    if (!["alters", "chronogene"].contains(filterName))
      throw null
    return { itemTemplate, type = filterName, sortingPriority }
  }) ?? [])

let secondaryGenesItemsInrow = 2
let secondaryGeneEquipped = Computed(@() [].extend(
  currentChronogenes.get()?.secondaryChronogenes ?? []
))

function getSecondaryGenesList() {
  let equipped = secondaryGeneEquipped.get()
  return [].extend(
    stashItems.get() ?? [],
    equipment.get().values() ?? []
  ).filter(@(item) item?.filterType == "chronogene" && !equipped.contains(item?.uniqueId))
}
let secondaryGenesListWatcheds = freeze(getWatcheds(getSecondaryGenesList))

let numDisplayedSecondaryChronogenes = Watched(0)

function patchSecondaryGenes(items) {
  return items.map(@(item) item.__merge({ isDragAndDropAvailable = false, slotName = null }))
}

let chronogenesSorting = @(a, b) (b.sortingPriority ?? 0) <=> (a.sortingPriority ?? 0) || a.itemTemplate <=> b.itemTemplate

let secondaryProcessItems = function(items) {
  items = patchSecondaryGenes(items)
  items = mergeNonUniqueItems(items)
  items.sort(chronogenesSorting)
  numDisplayedSecondaryChronogenes.set(items.len())

  items.extend(allChronogenesInGame.get()
    ?.filter(@(i) i.type == "chronogene" && items.findindex(@(v) v.itemTemplate == i.itemTemplate) == null)
    ?.sort(chronogenesSorting)
    ?.map(@(i) mkFakeItem(i.itemTemplate, {
      isDragAndDropAvailable = false
      forceLockIcon = true
      iconParamsOverride = {
        picSaturate = 0
        opacity = 0.5
      }
    })) ?? [])

  return items
}

let secondaryPanelsData = setupPanelsData(getSecondaryGenesList,
                                 secondaryGenesItemsInrow,
                                 [allChronogenesInGame, secondaryGeneEquipped, currentChronogenes].extend(secondaryGenesListWatcheds),
                                 secondaryProcessItems)

function inventorySecondaryGenes() {
  secondaryPanelsData.resetScrollHandlerData()

  let inventoryPanelParams = panelParams.__merge({
    size = flex()
    halign = ALIGN_CENTER
    padding = [ 0, 0, hdpx(10), hdpx(5) ]
  })

  let children = itemsPanelList({
    outScrollHandlerInfo=secondaryPanelsData.scrollHandlerData,
    list_type=GENES_SECONDARY,
    itemsPanelData=secondaryPanelsData.itemsPanelData,
    headers=[{
      size = [ flex(), SIZE_TO_CONTENT ]
      halign = ALIGN_CENTER
      children = mkText(loc("clonesMenu/secondaryGenesInventoryTitle"))
      padding = hdpx(3)
    }],
    can_drop_dragged_cb=@ (item) isItemCanBeDroppedInGenes(item, GENES_SECONDARY),
    on_item_dropped_to_list_cb=function(data, _list_type) {
      unequipChronogene(data)
    },
    item_actions={
      lmbAction = function(chronogene) {
        equipChronogene(chronogene)
      }
    },
    visualParams={
      size = [ hdpx(260), flex() ]
      halign = ALIGN_CENTER
    },
    listVisualParams=inventoryPanelParams
  })

  return {
    size = [ SIZE_TO_CONTENT, flex() ]
    watch = [ secondaryPanelsData.numberOfPanels, numDisplayedSecondaryChronogenes ]
    children
    onAttach = secondaryPanelsData.onAttach
    onDetach = secondaryPanelsData.onDetach
  }
}

let primaryGenesFilter = function(item) {
  return item && item?.filterType == "alters"
}

let getPrimaryGenesList = @() [].extend(
  stashItems.get() ? stashItems.get().filter(primaryGenesFilter) : [],
  equipment.get().map(@(v) v.__merge({
    slot = null 
    slotName = null
  })).values().filter(primaryGenesFilter) ?? []
)
let primaryGenesListWatcheds = freeze(getWatcheds(getPrimaryGenesList))

return {
  inventorySecondaryGenes,
  selectedMainChronogeneItem
  secondaryGeneEquipped
  getSecondaryGenesList
  secondaryGenesListWatcheds
  getPrimaryGenesList
  primaryGenesListWatcheds
  tryEquipGeneToContainer
  allChronogenesInGame
  chronogenesSorting
}