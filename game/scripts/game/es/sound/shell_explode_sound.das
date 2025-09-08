require ecs
require soundEvent
require shellSoundProps
require game.events.events_game
require strings


[es(tag=sound, REQUIRE=msg_sink)]
def shell_explode_sound(evt : EventOnShellExploded)
  let shellSoundProps = shell_sound_try_get_props(int(evt.shellId))
  if shellSoundProps != null && !empty(shellSoundProps.explosionPath)
    oneshot(shellSoundProps.explosionPath, evt.explPos) // shell explosion sound
