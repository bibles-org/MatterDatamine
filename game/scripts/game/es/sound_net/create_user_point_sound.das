require app
require ecs
require game.utils.sound_utils
require strings
require player


[es(on_appear, tag=server)]
def create_user_point_sound(evt : Event;
                            userPointOwner : EntityId;
                            userPointType : string;
                            silentAppearance : bool;
                            transform : float3x4)
  if !empty(userPointType) && !silentAppearance
    query(userPointOwner) <| $ [es] (possessed : EntityId)
      let path = "uiMap_{userPointType}"
      let team = get_int(possessed, "team") ?? TEAM_UNASSIGNED
      if team != TEAM_UNASSIGNED
        broadcast_net_sound(possessed, path, transform[3], 0./*param*/, team)
      else
        send_net_sound(possessed, path, transform[3])
