from "%ui/components/commonComponents.nut" import mkSelectPanelItem, VertSmallSelectPanelGap, BD_RIGHT
from "%ui/ui_library.nut" import *

#allow-auto-freeze

let picSize = hdpxi(22)
let allFilters = [
  { key = "weapons", image = Picture("!ui/skin#itemFilter/weapons.svg:{0}:{0}:P".subst(picSize)) }
  { key = "weapon_mods", image = Picture("!ui/skin#itemFilter/weapon_mods.svg:{0}:{0}:P".subst(picSize)) }
  { key = "ammunition", image = Picture("!ui/skin#itemFilter/ammunition.svg:{0}:{0}:P".subst(picSize)) }
  { key = "medicines", image = Picture("!ui/skin#itemFilter/medicines.svg:{0}:{0}:P".subst(picSize)) }
  { key = "equipment", image = Picture("!ui/skin#itemFilter/equipment.svg:{0}:{0}:P".subst(picSize)) }
  { key = "keys", image = Picture("!ui/skin#itemFilter/keys.svg:{0}:{0}:P".subst(picSize)) }
  { key = "dog_tags", image = Picture("!ui/skin#microchip.svg:{0}:{0}:P".subst(picSize)) }
  { key = "loot", image = Picture("!ui/skin#itemFilter/loot.svg:{0}:{0}:P".subst(picSize)) }
  { key = "enriched", image = Picture("!ui/skin#itemFilter/only_enriched.svg:{0}:{0}:P".subst(picSize)) }
  { key = "notEnriched", image = Picture("!ui/skin#itemFilter/only_not_enriched.svg:{0}:{0}:P".subst(picSize)) }
]

let resetPic = Picture("!ui/skin#itemFilter/all.svg:{0}:{0}:K".subst(picSize))

let state = Watched((1 << allFilters.len()))

let activeFilters = Computed(function() {
  #forbid-auto-freeze
  let ret = []
  let st = state.get()
  for(local idx=0; idx < allFilters.len(); idx++){
    if ( (st & (1 << idx)) > 0 )
      ret.append(allFilters[idx].key)
  }
  return ret
})

let mkFilterButton = @(image, idx, cb=null, needToShow = Watched(true)) function() {
  let watch = needToShow
  if (!needToShow.get())
    return { watch }
  return {
    watch
    children = mkSelectPanelItem( {
      children = {
        rendObj = ROBJ_IMAGE
        image
        opacity = 0.9
        size = static [picSize, picSize]
      }
      idx
      multi = true
      state
      tooltip_text = idx < allFilters.len() ? loc($"stashFilter/{allFilters[idx].key}") : static loc("stashFilter/all")
      visual_params = static {
        size = SIZE_TO_CONTENT
        padding = hdpx(5)
      }
      onSelect = cb
      border_align = BD_RIGHT
    })
  }
}

function resetFilters() {
  state.set(1 << allFilters.len())
}

function releaseFilterAll(v) {
  if (v && ( (1 << allFilters.len() & state.get()) > 0 )) {
    state.set(state.get() ^ (1 << allFilters.len()))
  }
  else if(state.get() == 0) {
    resetFilters()
  }
}

function mkFilter(idx) {
  let { image, needToShow = Watched(true) } = allFilters[idx]
  return mkFilterButton(image, idx, releaseFilterAll, needToShow)
}

function inventoryFiltersWidget() {
  #forbid-auto-freeze
  let buttons = [ mkFilterButton(resetPic, allFilters.len(), @(_) resetFilters()) ]
  for (local idx=0; idx < allFilters.len(); idx++) {
    buttons.append(mkFilter(idx))
  }
  #allow-auto-freeze
  return {
    onAttach = function() {
      state.set((1 << allFilters.len()))
    }
    flow = FLOW_VERTICAL
    gap = VertSmallSelectPanelGap
    children = buttons
  }
}


return {
  inventoryFiltersWidget
  activeFilters
  resetFilters
  allFilters
}