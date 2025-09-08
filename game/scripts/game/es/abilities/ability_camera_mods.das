require ecs
require DagorSystem
require game.utils.hero
require game.events.events

[es(on_appear)]
def ability_camera_offset_set_es(evt : Event; game_effect__attachedTo : EntityId;
                                 game_effect__cameraOffset : float3)
  if has(game_effect__attachedTo, "hero")
    ecs::query(game_effect__attachedTo) <| $ [es] (bindedCamera : EntityId;
                                                   var human_inventory__pickupTpsFrustum__cameraOffset : float?;
                                                   human_inventory__pickupTpsFrustum__cameraOffsetDefault : float const?)
      ecs::query(bindedCamera) <| $ [es] (var shooter_cam__wishAdditionalOffset : float3&)
        shooter_cam__wishAdditionalOffset = game_effect__cameraOffset
        if human_inventory__pickupTpsFrustum__cameraOffset != null && human_inventory__pickupTpsFrustum__cameraOffsetDefault != null
          *human_inventory__pickupTpsFrustum__cameraOffset = *human_inventory__pickupTpsFrustum__cameraOffsetDefault - game_effect__cameraOffset.z
          sendEvent(game_effect__attachedTo, EventOnModsChanged())

[es(on_event=EventEntityDestroyed, REQUIRE=game_effect__cameraOffset)]
def ability_camera_offset_reset_es(evt : Event; game_effect__attachedTo : EntityId)
  if has(game_effect__attachedTo, "hero")
    ecs::query(game_effect__attachedTo) <| $ [es] (bindedCamera : EntityId;
                                                   var human_inventory__pickupTpsFrustum__cameraOffset : float?;
                                                   human_inventory__pickupTpsFrustum__cameraOffsetDefault : float const?)
      ecs::query(bindedCamera) <| $ [es] (var shooter_cam__wishAdditionalOffset : float3&)
        shooter_cam__wishAdditionalOffset = float3(0, 0, 0)
        if human_inventory__pickupTpsFrustum__cameraOffset != null && human_inventory__pickupTpsFrustum__cameraOffsetDefault != null
          *human_inventory__pickupTpsFrustum__cameraOffset = *human_inventory__pickupTpsFrustum__cameraOffsetDefault
          sendEvent(game_effect__attachedTo, EventOnModsChanged())

[es(track=bindedCamera, REQUIRE=hero)]
def ability_camera_offset_track_camera_es(evt : Event; bindedCamera : EntityId;
                                          var human_inventory__pickupTpsFrustum__cameraOffset : float?;
                                          human_inventory__pickupTpsFrustum__cameraOffsetDefault : float const?)
  query(bindedCamera) <| $ [es] (camera__target : EntityId; var shooter_cam__wishAdditionalOffset : float3&)
    query() <| $ [es] (game_effect__attachedTo : EntityId; game_effect__cameraOffset : float3)
      if camera__target == game_effect__attachedTo
        shooter_cam__wishAdditionalOffset = game_effect__cameraOffset
        if human_inventory__pickupTpsFrustum__cameraOffset != null && human_inventory__pickupTpsFrustum__cameraOffsetDefault != null
          *human_inventory__pickupTpsFrustum__cameraOffset = *human_inventory__pickupTpsFrustum__cameraOffsetDefault - game_effect__cameraOffset.z
          sendEvent(game_effect__attachedTo, EventOnModsChanged())

[es(on_appear)]
def ability_camera_magnification_set_es(evt : Event; game_effect__attachedTo : EntityId;
                                        game_effect__cameraMagnification : float)
  if has(game_effect__attachedTo, "hero")
    ecs::query(game_effect__attachedTo) <| $ [es] (bindedCamera : EntityId)
      ecs::query(bindedCamera) <| $ [es] (var shooter_cam__wishMagnificationMult : float&)
        shooter_cam__wishMagnificationMult = game_effect__cameraMagnification

[es(on_event=EventEntityDestroyed, REQUIRE=game_effect__cameraMagnification)]
def ability_camera_magnification_reset_es(evt : Event; game_effect__attachedTo : EntityId)
  if has(game_effect__attachedTo, "hero")
    ecs::query(game_effect__attachedTo) <| $ [es] (bindedCamera : EntityId)
      ecs::query(bindedCamera) <| $ [es] (var shooter_cam__wishMagnificationMult : float&)
        shooter_cam__wishMagnificationMult = 1.0

[es(track=camera__active, REQUIRE=game_effect__cameraOffset)]
def ability_camera_magnification_track_camera_es(evt : Event; camera__active : bool; camera__target : EntityId; var shooter_cam__wishMagnificationMult : float&)
  query() <| $ [es] (game_effect__attachedTo : EntityId; game_effect__cameraMagnification : float)
    if camera__target == game_effect__attachedTo
      shooter_cam__wishMagnificationMult = camera__active ? game_effect__cameraMagnification : 1.0

[es(on_appear)]
def ability_camera_tau_set_es(evt : Event; game_effect__attachedTo : EntityId;
                              game_effect__cameraTauMult : float)
  if has(game_effect__attachedTo, "hero")
    ecs::query(game_effect__attachedTo) <| $ [es] (bindedCamera : EntityId)
      ecs::query(bindedCamera) <| $ [es] (var shooter_cam__tauMult : float&; var shooter_cam__velTauMult : float&)
        shooter_cam__tauMult = game_effect__cameraTauMult
        shooter_cam__velTauMult = game_effect__cameraTauMult

[es(on_event=EventEntityDestroyed, REQUIRE=game_effect__cameraTauMult)]
def ability_camera_tau_reset_es(evt : Event; game_effect__attachedTo : EntityId)
  if has(game_effect__attachedTo, "hero")
    ecs::query(game_effect__attachedTo) <| $ [es] (bindedCamera : EntityId)
      ecs::query(bindedCamera) <| $ [es] (var shooter_cam__tauMult : float&; var shooter_cam__velTauMult : float&)
        shooter_cam__tauMult = 1.0
        shooter_cam__velTauMult = 1.0

