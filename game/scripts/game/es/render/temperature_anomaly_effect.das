require ecs
require math


[es(tag=render, on_appear, after=(axis_aligned_transform_appear))]
def temperature_anomaly_appear(evt : Event; transform : float3x4; var temperature_anomaly__initialScale : float&)
  let len0 = length(transform[0])
  let len1 = length(transform[1])
  let len2 = length(transform[2])
  temperature_anomaly__initialScale = max(len0, len1) |> max(len2)


[es(tag=render, no_order)]
def smooth_appear_temperature_anomaly(act : UpdateStageInfoAct;
                                      game_effect__attachedAt : float;
                                      game_effect__destroyAt, game_effect__timeToDestroy : float const?;
                                      game_effect__screenBleedDecaySmoothTime = 2f;
                                      temperature_anomaly__initialScale : float;
                                      game_effect__temperatureAnomalyBreathSpeed = 1.;
                                      game_effect__temperatureAnomalyBreathSmooth = float2(0.9, 1.);
                                      game_effect__temperatureAnomalyIntensitySmooth = float2(0.0001, 1.0);
                                      var temperature_anomaly__intensity : float&;
                                      var temperature_anomaly__radius : float&)
  let destroying = game_effect__destroyAt != null && *game_effect__destroyAt >= 0.
  let time = destroying ? *game_effect__destroyAt - act.curTime : act.curTime - game_effect__attachedAt
  let totalTime = destroying ? game_effect__timeToDestroy ?? game_effect__screenBleedDecaySmoothTime : game_effect__screenBleedDecaySmoothTime
  let breathTime = sin(act.curTime * game_effect__temperatureAnomalyBreathSpeed)
  let breathProgress = pow(lerp(game_effect__temperatureAnomalyBreathSmooth.x, game_effect__temperatureAnomalyBreathSmooth.y, breathTime), 0.5)
  let progress = saturate(time / totalTime) * breathProgress
  temperature_anomaly__intensity = lerp(game_effect__temperatureAnomalyIntensitySmooth.x, game_effect__temperatureAnomalyIntensitySmooth.y, progress)
  let scale = pow(progress, 0.5) * breathProgress * temperature_anomaly__initialScale
  temperature_anomaly__radius = scale * 0.5


[es(tag=render, no_order)]
def smooth_appear_metal_heat_light(act : UpdateStageInfoAct;
                                   game_effect__attachedAt : float;
                                   game_effect__destroyAt, game_effect__timeToDestroy : float const?;
                                   game_effect__lightBrightnessSmoothTime = 2f;
                                   game_effect__lightBrightnessSmooth = float2(0.1, 1.);
                                   var light__brightness : float&)
  let destroying = game_effect__destroyAt != null && *game_effect__destroyAt >= 0.
  let time = destroying ? *game_effect__destroyAt - act.curTime : act.curTime - game_effect__attachedAt
  let totalTime = destroying ? game_effect__timeToDestroy ?? game_effect__lightBrightnessSmoothTime : game_effect__lightBrightnessSmoothTime
  let progress = saturate(time / totalTime)
  light__brightness = lerp(game_effect__lightBrightnessSmooth.x, game_effect__lightBrightnessSmooth.y, progress)
