from "%ui/ui_library.nut" import *

let {safeAreaHorPadding, safeAreaVerPadding} = require("%ui/options/safeArea.nut")

function mkViewport(padding){
  return {
    sortOrder = -999
    size = [sw(100) - safeAreaHorPadding.get()*2 - padding, sh(100) - safeAreaVerPadding.get()*2 - padding]
    data = {
      isViewport = true
    }
  }
}

function layout(state, ctors, padding){
  let child = mkViewport(padding)
  if (type(ctors) != "array")
    ctors = [ctors]

  return function() {
    let children = [child]
    foreach(ctor in ctors)
      foreach (eid, info in state.get())
        children.append(ctor(eid, info))
    return {
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      size = flex()
      children = children
      watch = state
      behavior = DngBhv.Projection
      sortChildren = true
    }
  }
}

function makeMarkersLayout(stateAndCtors, padding){

  let layers = []
  foreach (state, ctors in stateAndCtors){
    layers.append(layout(state, ctors, padding))
  }

  return @(){
    size = [sw(100), sh(100)]
    children = layers
    watch = safeAreaVerPadding
  }
}

return {
  makeMarkersLayout
  layout
}
