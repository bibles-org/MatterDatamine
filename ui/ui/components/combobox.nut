from "%ui/ui_library.nut" import *

let {mkSelectWindow, mkOpenSelectWindowBtn} = require("%ui/components/selectWindow.nut")

function comboBox(state, values, title=null, tooltipText=null){
  let openScenesMenu = mkSelectWindow({
    uid = "combobox",
    optionsState = values,
    state,
    title,
    filterState = null
    tooltipText
  })
  return mkOpenSelectWindowBtn(state, openScenesMenu)
}

return comboBox