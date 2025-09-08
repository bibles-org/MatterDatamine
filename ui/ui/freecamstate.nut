from "%ui/ui_library.nut" import *
import "%dngscripts/ecs.nut" as ecs

let freeCameraState = Watched(false)

ecs.register_es("free_camera_state_ui_es",
  {
    [["onInit", "onChange"]] = @(_evt, _eid, comp) freeCameraState.set(comp["camera__active"]),
    onDestroy = @(...) freeCameraState.set(false),
  },
  {
    comps_track = [
      ["camera__active", ecs.TYPE_BOOL],
    ],
    comps_rq = ["free_cam__move_speed"]
  },
)

return {freeCameraState}