from "%ui/ui_library.nut" import *

let {user_points} = require("%ui/hud/state/user_points.nut")
let {user_points_ctors, mkUserPoints} = require("user_points_ctors.nut")

return {
  userPoints = mkUserPoints(user_points_ctors, user_points)
}