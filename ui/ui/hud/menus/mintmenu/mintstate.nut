from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

from "%ui/hud/hud_menus_state.nut" import convertMenuId, currentMenuId
from "%ui/equipPresets/presetsState.nut" import previewPreset
from "math" import pow

let agencyLoadoutGenerators = Watched([])
const PREPARATION_NEXUS_SUBMENU_ID = "PREPARATION_NEXUS_SUBMENU_ID"

ecs.register_es("nexus_agency_loadouts_init", {
  onInit = function(_evt, _eid, comp) {
    let generators = comp.nexus_agency_loadouts__generators.getAll()
    let names = comp.nexus_agency_loadouts__names.getAll()
    let isFreeList = comp.nexus_agency_loadouts__isFree.getAll()
    agencyLoadoutGenerators.mutate(function(v) {
      for (local i = 0; i < comp.nexus_agency_loadouts__generators.getAll().len(); i++) {
        v.append({
          generator = generators[i]
          name = loc(names[i])
          isFree = isFreeList[i]
        })
      }
    })
  }
  onDestroy = function(_evt, _eid, _comp) {
    agencyLoadoutGenerators.set([])
  }
}, {
  comps_ro =[
    ["nexus_agency_loadouts__generators", ecs.TYPE_STRING_LIST],
    ["nexus_agency_loadouts__names", ecs.TYPE_STRING_LIST],
    ["nexus_agency_loadouts__isFree", ecs.TYPE_BOOL_LIST]
  ]
},
{
  tags = "gameClient"
})


function calcCost(cost, increaseAfterCount, currentCount) {
  return cost * pow(2, currentCount.tointeger() / increaseAfterCount.tointeger())
}

function setPriceOfTemplate(templateName, prices) {
  if (templateName == null)
    return

  let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(templateName)
  if (!template)
    return

  let item__nexusCost = template?.getCompValNullable("item__nexusCost")
  let item__nexusIncreaseCostAfterCount = template?.getCompValNullable("item__nexusIncreaseCostAfterCount") ?? 10000 

  if (item__nexusCost == null)
    return

  let curCount = (prices?[templateName].count ?? 0)
  let curOvrallCost = (prices?[templateName].overallCost ?? 0)
  prices[templateName] <- {
    count = curCount + 1
    cost = calcCost(item__nexusCost, item__nexusIncreaseCostAfterCount, curCount + 1)
    overallCost = curOvrallCost + calcCost(item__nexusCost, item__nexusIncreaseCostAfterCount, curCount)
  }
}


function updateNexusCostsOfPreviewPreset() {
  function setPreviewCost(ppItem, scores) {
    let itemTemplateName = ppItem?.itemTemplate
    if (itemTemplateName == null)
      return

    let template = ecs.g_entity_mgr.getTemplateDB().getTemplateByName(itemTemplateName)

    let item__nexusCost = template?.getCompValNullable("item__nexusCost")

    if (item__nexusCost == null)
      return

    ppItem.__update({
      nexusCost = scores?[itemTemplateName].cost ?? item__nexusCost
    })

    setPriceOfTemplate(itemTemplateName, scores)
  }

  let scorePrices = {}
  previewPreset.mutate(function(pp) {
    setPreviewCost(pp?.flashlight, scorePrices)
    setPreviewCost(pp?.helmet, scorePrices)
    setPreviewCost(pp?.backpack, scorePrices)
    setPreviewCost(pp?.pouch, scorePrices)

    foreach (_k, v in pp?.pouch.attachments ?? {})
      setPreviewCost(v, scorePrices)

    foreach (_k, v in pp?.helmet.attachments ?? {})
      setPreviewCost(v, scorePrices)

    foreach (_k, v in pp?.chronogene_primary_1 ?? {})
      setPreviewCost(v, scorePrices)

    foreach (v in pp?.inventories.myItems.items ?? [])
      setPreviewCost(v, scorePrices)

    foreach (v in pp?.inventories.backpack.items ?? [])
      setPreviewCost(v, scorePrices)

    foreach (weap in pp?.weapons ?? []) {
      setPreviewCost(weap, scorePrices)
      foreach (_k, v in weap?.attachments ?? {}) {
        setPreviewCost(v, scorePrices)
      }
    }
  })
}


let nexusItemCost = Computed(function() {
  if (convertMenuId(currentMenuId.get())[1]?[0] != PREPARATION_NEXUS_SUBMENU_ID)
    return null

  let scorePrices = {}

  let pp = previewPreset.get()

  foreach (_k, v in pp ?? {}) {
    if (v?.itemTemplate)
      setPriceOfTemplate(v.itemTemplate, scorePrices)
  }

  foreach (_k, v in pp?.pouch.attachments ?? {})
    setPriceOfTemplate(v.itemTemplate, scorePrices)

  foreach (_k, v in pp?.helmet.attachments ?? {})
    setPriceOfTemplate(v.itemTemplate, scorePrices)

  foreach (_k, v in pp?.chronogene_primary_1 ?? {})
    setPriceOfTemplate(v?.itemTemplate, scorePrices)

  foreach (v in pp?.inventories.myItems.items ?? [])
    setPriceOfTemplate(v.itemTemplate, scorePrices)

  foreach (v in pp?.inventories.backpack.items ?? [])
    setPriceOfTemplate(v.itemTemplate, scorePrices)

  foreach (weap in pp?.weapons ?? []) {
    setPriceOfTemplate(weap?.itemTemplate, scorePrices)
    foreach (_k, v in weap?.attachments ?? {}) {
      setPriceOfTemplate(v?.itemTemplate, scorePrices)
    }
  }

  return scorePrices
})

function getCostOfPreset(pp) {
  let scorePrices = {}

  foreach (_k, v in pp ?? {}) {
    if (v?.itemTemplate)
      setPriceOfTemplate(v.itemTemplate, scorePrices)
  }

  foreach (_k, v in pp?.pouch.attachments ?? {})
    setPriceOfTemplate(v.itemTemplate, scorePrices)

  foreach (_k, v in pp?.helmet.attachments ?? {})
    setPriceOfTemplate(v.itemTemplate, scorePrices)

  foreach (_k, v in pp?.chronogene_primary_1 ?? {})
    setPriceOfTemplate(v?.itemTemplate, scorePrices)

  foreach (v in pp?.inventories.myItems.items ?? [])
    setPriceOfTemplate(v.itemTemplate, scorePrices)

  foreach (v in pp?.inventories.backpack.items ?? [])
    setPriceOfTemplate(v.itemTemplate, scorePrices)

  foreach (weap in pp?.weapons ?? []) {
    setPriceOfTemplate(weap?.itemTemplate, scorePrices)
    foreach (_k, v in weap?.attachments ?? {}) {
      setPriceOfTemplate(v?.itemTemplate, scorePrices)
    }
  }

  local overallScores = 0

  foreach(_k, v in scorePrices) {
    overallScores += v.overallCost
  }


  return overallScores
}

return {
  agencyLoadoutGenerators
  PREPARATION_NEXUS_SUBMENU_ID
  nexusItemCost
  updateNexusCostsOfPreviewPreset
  getCostOfPreset
}