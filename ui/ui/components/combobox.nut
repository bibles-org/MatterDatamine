from "%ui/components/selectWindow.nut" import mkSelectWindow, mkOpenSelectWindowBtn

from "%ui/ui_library.nut" import *

#allow-auto-freeze

function comboBox(state, values, title=null, defBtnText = null, columns = 4, titleStyle = {} ){
  let openScenesMenu = mkSelectWindow({
    uid = "combobox",
    optionsState = values,
    state,
    title,
    filterState = null
    columns
    titleStyle
  })
  return mkOpenSelectWindowBtn(state, openScenesMenu, @(v) v, null, null, null, defBtnText)
}

return comboBox