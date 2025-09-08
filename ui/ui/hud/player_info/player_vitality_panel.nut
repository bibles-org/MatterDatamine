from "%ui/ui_library.nut" import *

let panelSize = [ 50, 100 ] 

function mkMoveablePanel(panel, customHdpxi, panelsVisibility, idx, override) {
  return function() {
    local hidenCount = 0
    for (local i = 0; i < idx; i++) {
      if (!panelsVisibility[i].get())
        hidenCount++
    }
    let posMult = idx - hidenCount + 1

    let currentShowedCount = panelsVisibility.filter(@(v) v.get()).len()
    let sectionHeight = customHdpxi(panelSize[1]) / (currentShowedCount + 1)

    return {
      watch = panelsVisibility
      size = [ 0, 0 ]
      halign = ALIGN_LEFT
      children = panelsVisibility[idx].get() ? panel(customHdpxi, override) : null

      transform = {
        translate = [ 0, sectionHeight * posMult ]
      }
      transitions = [
        { prop = AnimProp.translate, duration = 0.2, easing = OutQuintic }
      ]
    }
  }
}

function mkVitalityPanel(panels, customHdpxi=hdpxi, override = {}) {
  let panelsVisibility = panels.map(@(v) v.visibleWatched)

  return {
    size = [ customHdpxi(panelSize[0]), customHdpxi(panelSize[1]) ]
    children = panels.map(@(v, idx) mkMoveablePanel(
      v.panel,
      customHdpxi,
      panelsVisibility,
      idx
      override
    ))
  }
}

return {
  mkVitalityPanel
}