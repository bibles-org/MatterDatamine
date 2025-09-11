from "%ui/hud/hud_objective_photograph.nut" import photographObjective

from "%ui/ui_library.nut" import *


return function () {
  return {
    size = flex()

    children = [
      photographObjective
    ]
  }
}