from "%ui/ui_library.nut" import *
let { activeFilters, allFilters } = require("%ui/hud/menus/components/inventoryStashFiltersWidget.nut")


function filterItemByInventoryFilter(item) {
  if (activeFilters.get().len() == 0)
    return true

  let filterTypeActive = activeFilters.get().reduce(@(acc, v) (v != "enriched" && v != "notEnriched") || acc, false)
  let enrichedOnly = activeFilters.get().findindex(@(v) v == "enriched") != null
  let notEnrichedOnly = activeFilters.get().findindex(@(v) v == "notEnriched") != null

  local filterTypeOK = true
  if (filterTypeActive) {
    if (allFilters.findindex(@(v) v.key == item.filterType) != null)
      filterTypeOK = activeFilters.get().findindex(@(v) v == item.filterType) != null
    else
      filterTypeOK = activeFilters.get().findindex(@(v) v == "loot") != null 
  }
  local filterEnrichedOk = true
  if ( enrichedOnly != notEnrichedOnly) {
    if (enrichedOnly)
      filterEnrichedOk = filterEnrichedOk && item.isCorrupted
    if (notEnrichedOnly)
      filterEnrichedOk = filterEnrichedOk && !item.isCorrupted
  }

  return filterTypeOK && filterEnrichedOk
}

return {
  filterItemByInventoryFilter
}