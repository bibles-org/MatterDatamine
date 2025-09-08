from "%ui/ui_library.nut" import *

let platform = require("%dngscripts/platform.nut")
let { getCurrentLoginUi, setCurrentLoginUi } = require("currentLoginUi.nut")
let { setStagesConfig, isStagesInited } = require("login_chain.nut")
let { linkSteamAccount } = require("%ui/login/login_state.nut")
let { disableRemoteNetServices } = require("%sqGlob/offline_mode.nut")

if (!isStagesInited.value)
  setStagesConfig(require("defaultLoginStages.nut"))

if (getCurrentLoginUi() == null) { 

  if (disableRemoteNetServices)
    setCurrentLoginUi(require("%ui/login/ui/fake.nut"))
  else if (platform.is_xbox)
    setCurrentLoginUi(require("%ui/login/ui/xbox.nut"))
  else if (platform.is_sony)
    setCurrentLoginUi(require("%ui/login/ui/sony.nut"))
  else {
    let steam = require("steam")

    let updatePcComp = function() {
      if (steam.is_running() && !linkSteamAccount.value)
        setCurrentLoginUi(require("%ui/login/ui/steam.nut"))
      else
        setCurrentLoginUi(require("%ui/login/ui/go.nut"))
    }

    if (steam.is_running())
      linkSteamAccount.subscribe(@(_) updatePcComp())
    updatePcComp()
  }
}
