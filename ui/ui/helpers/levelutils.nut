import "%dngscripts/ecs.nut" as ecs

let { parse_level_weather_and_time_from_scene } = require("das.level")

function patchMatchingQueuesWithLevelInfo(queues) {
  queues.each(function(queue){
    if (queue?.scenes != null && queue.scenes.len() > 0) {
      local scenePath = queue.scenes?[0].fileName
      if (scenePath==null)
        return
      local envInfo = ecs.CompObject()
      if (parse_level_weather_and_time_from_scene(scenePath, envInfo))
        queue.envInfo <- envInfo.getAll()
    }
  })
  return queues
}

return {
  patchMatchingQueuesWithLevelInfo
}
