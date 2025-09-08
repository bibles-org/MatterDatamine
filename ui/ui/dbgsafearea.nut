from "%ui/ui_library.nut" import *

let {safeAreaShow, safeAreaAmount} = require("%ui/options/safeArea.nut")
function dbgSafeArea(){
  return {
    size = [sw(100*safeAreaAmount.get()), sh(100*safeAreaAmount.get())]
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    rendObj = safeAreaShow.get() ? ROBJ_FRAME : null
    watch = [safeAreaShow, safeAreaAmount]
    color = Color(255,128,128)
    borderWidth = 1
  }
}

return { dbgSafeArea }