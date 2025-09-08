from "%ui/ui_library.nut" import *

let { photographObjective } = require("%ui/hud/hud_objective_photograph.nut")

return function () {
  return {
    size = flex()

    children = [
      photographObjective
    ]
  }
}