from "%ui/ui_library.nut" import *
from "%dngscripts/globalState.nut" import nestWatched
let showSettingsMenu = nestWatched("showSettingsMenu", false)
let showControlsMenu = nestWatched("showControlsMenu", false)
return {showSettingsMenu, showControlsMenu}