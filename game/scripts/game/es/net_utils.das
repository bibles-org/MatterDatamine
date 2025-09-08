require ecs
require game.events.events_game


[es]
def cmd_update_transform(evt : CmdUpdateTransform;
                         var transform : float3x4&)
  transform = evt.tm