from "%ui/components/commonComponents.nut" import mkTabs
from "%ui/components/uiHotkeysHint.nut" import mkHotkey

from "%ui/ui_library.nut" import *


function settingsHeaderTabs(currentTab, sourceTabs) {
  let cTab = currentTab

  function changeTab(delta, cycle=false){
    let tabsSrc = sourceTabs
    foreach (idx, tab in tabsSrc) {
      if (cTab.get() == tab.id) {
        local next_idx = idx+delta
        let total = tabsSrc.len()
        next_idx = cycle ? ((next_idx+total)%total) : clamp(next_idx, 0, total-1)
        cTab.set(tabsSrc[next_idx].id)
        break
      }
    }
  }
  let changeTabWrap = @(delta) changeTab(delta, true)

  let hotkeys_children = [
    mkHotkey("^J:LB", @() changeTab(-1)),
    mkHotkey("^J:RB", @() changeTab(1)),
    {hotkeys = [["^Tab", @() changeTabWrap(1)], ["^L.Shift Tab | R.Shift Tab", @() changeTabWrap(-1)]]}
  ]

  function tabsHotkeys(){
    return {
      size = 0
      valign = ALIGN_BOTTOM
      children = {
        flow = FLOW_HORIZONTAL
        gap = fsh(0.25)
        pos = [0, fsh(0.5)]
        children = hotkeys_children
      }
    }
  }

  function tabsContainer() {
    return {
      watch = cTab
      size = SIZE_TO_CONTENT
      children = mkTabs({
        tabs = sourceTabs
        currentTab = cTab.get()
        onChange = @(tab) cTab.set(tab?.id)
      })
    }
  }

  return function() {
    return {
      size = FLEX_H
      children = [
        sourceTabs.len() > 1 ? tabsHotkeys : null
        tabsContainer
      ]
    }
  }
}


return settingsHeaderTabs
