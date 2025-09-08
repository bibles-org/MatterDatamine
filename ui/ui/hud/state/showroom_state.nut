import "%dngscripts/ecs.nut" as ecs
from "%ui/ui_library.nut" import *

let showroomActive = Watched(false)

ecs.register_es("track_showroom_active_es",
  {
    [[ "onInit", "onChange" ]] = function(_evt, _eid, comp){
      showroomActive.set(comp["camera__active"])
    },

    onDestroy = @(_evt, _eid, _comp) showroomActive.set(false)
  },
  {
    comps_track = [["camera__active", ecs.TYPE_BOOL]]
    comps_rq = ["showroom_cam__itemPlaceEid"]
  }
)


return{
  showroomActive
}
