from "%ui/ui_library.nut" import *

enum craftScreens {
  craftProgress = 1
  craftSelection = 2
}

let craftScreenState = Watched(craftScreens.craftProgress)

return {
  craftScreens
  craftScreenState
}