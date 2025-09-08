require ecs
require ecs.safe
require ecs.common
require game.events.events_game


[es(tag=gameClient, track=(human__lockPersonView, isAlive, isDowned), REQUIRE=hero)]
def human_lock_person_view_es(evt : Event;
                              possessedByPlr : EntityId;
                              isAlive, isDowned : bool;
                              camNames : Array;
                              var human__lockSwitchCamera : bool&;
                              human__lockPersonView : int = 0)
  if human__lockPersonView > 0
    for i in iter_range(camNames)

      let cameraTemplateName = get_string(camNames[i], "")
      if cameraTemplateName == ""
        continue

      let templ = getTemplateByName(cameraTemplateName)
      if templ == null
        continue

      let component = getTemplateComponent(*templ, "isTpsView")
      if component == null
        continue
      let tpsCamera = component ?? false

      if human__lockPersonView == (tpsCamera ? 3 : 1)
        human__lockSwitchCamera = false
        sendEventImmediate(possessedByPlr, CmdSwitchCameraByIndex(index = i))
        break
  human__lockSwitchCamera = human__lockPersonView != 0 || isDowned || !isAlive
