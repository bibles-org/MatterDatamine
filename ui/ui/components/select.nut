from "%ui/ui_library.nut" import *
from "%ui/components/colors.nut" import BtnTextNormal, BtnTextHover, BtnTextActive, ComboboxBorderColor, BtnBgSelected, BtnBgHover, BtnBgNormal

let borderRadius = hdpx(1)
let borderWidth=1
let padding = hdpx(5)

let mkSelItem = @(state, extraChildren=null, onClickCtor=null, isCurrent=null, textCtor=null) function selItem(p, idx, list) {
  let stateFlags = Watched(0)
  isCurrent = isCurrent ?? @(v, _idx) v==state.value
  let onClick = onClickCtor!=null ? onClickCtor(p, idx) : @() state(p)
  let text = textCtor != null ? textCtor(p, idx, stateFlags) : p
  return function(){
    let selected = isCurrent(p, idx)
    local nBw = borderWidth
    if (list.len() > 2) {
      if (idx != list.len()-1 && idx != 0)
        nBw = [borderWidth,0,borderWidth,borderWidth]
      if (idx == 1)
        nBw = [borderWidth,0,borderWidth,0]
    }
    return {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_BOX
      onElemState = @(sf) stateFlags.set(sf)
      behavior = Behaviors.Button
      valign = ALIGN_CENTER
      halign = ALIGN_CENTER
      padding
      stopHover = true
      watch = [stateFlags, state]
      flow = FLOW_HORIZONTAL
      children = [
        {
          rendObj = ROBJ_TEXT, text=text,
          color = (stateFlags.get() & S_HOVER)
            ? BtnTextHover
            : selected
              ? BtnTextActive
              : BtnTextNormal,
          padding = borderRadius
        }
        extraChildren?[idx]
      ]
      onClick
      borderColor = ComboboxBorderColor
      borderWidth = nBw
      borderRadius = list.len()==1 || (borderRadius ?? 0)==0
        ? borderRadius
        : idx==0
          ? [borderRadius, 0, 0, borderRadius]
          : idx==list.len()-1
            ? [0,borderRadius, borderRadius, 0]
            : 0
      fillColor = stateFlags.get() & S_HOVER
        ? BtnBgHover
        : selected
          ? BtnBgSelected
          : BtnBgNormal
      xmbNode = XmbNode()
    }
  }
}

return kwarg(function select(state, options, extraChildren=null, onClickCtor=null, isCurrent=null, textCtor=null, root_style=null) {
  let selItem = mkSelItem(state, extraChildren, onClickCtor, isCurrent, textCtor)
  return function(){
    return {
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      children = options.map(selItem)
      xmbNode = XmbNode()
    }.__update(root_style ?? {})
  }
})
