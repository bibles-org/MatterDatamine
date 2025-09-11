from "%ui/loading/loading.nut" import loadingUI

from "%ui/ui_library.nut" import *
require("%ui/ui_config.nut")

let hud = require("%ui/hud/hud.nut")
let { dbgLoading } = require("%ui/loading/loading.nut")
let { levelLoaded, uiDisabled } = require("%ui/state/appState.nut")

function root() {
  let children = dbgLoading.get() || !levelLoaded.get()
    ? loadingUI
    : !uiDisabled.get()
      ? hud
      : null
  return {
    watch = [levelLoaded, uiDisabled, dbgLoading]
    size = flex()
    children
  }
}

return root
