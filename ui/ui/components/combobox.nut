from "%ui/components/selectWindow.nut" import mkSelectWindow, mkOpenSelectWindowBtn

from "%ui/ui_library.nut" import *

#allow-auto-freeze

function comboBox(state, values, title=null){
  let openScenesMenu = mkSelectWindow({
    uid = "combobox",
    optionsState = values,
    state,
    title,
    filterState = null
  })
  return mkOpenSelectWindowBtn(state, openScenesMenu)
}

return comboBox