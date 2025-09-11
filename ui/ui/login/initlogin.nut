from "%sqGlob/offline_mode.nut" import disableRemoteNetServices

from "%ui/login/currentLoginUi.nut" import getCurrentLoginUi, setCurrentLoginUi
from "%ui/login/login_chain.nut" import setStagesConfig

from "%ui/ui_library.nut" import *

let platform = require("%dngscripts/platform.nut")
let { isStagesInited } = require("%ui/login/login_chain.nut")
let { linkSteamAccount } = require("%ui/login/login_state.nut")

if (!isStagesInited.get())
  setStagesConfig(require("%ui/login/defaultLoginStages.nut"))

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
      if (steam.is_running() && !linkSteamAccount.get())
        setCurrentLoginUi(require("%ui/login/ui/steam.nut"))
      else
        setCurrentLoginUi(require("%ui/login/ui/go.nut"))
    }

    if (steam.is_running())
      linkSteamAccount.subscribe(@(_) updatePcComp())
    updatePcComp()
  }
}
