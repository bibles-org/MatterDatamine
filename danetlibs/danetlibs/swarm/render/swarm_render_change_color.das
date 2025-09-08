require ecs
require DagorShaders

[es(tag=render, track=swarm__emissionColor)]
def swarm_render_change_color(
                              evt : Event;
                              swarm__emissionColor : float3;
                              swarm__emissionChangeDuration : float;
                              var swarm__emissionColor1, swarm__emissionColor2 : float4&
                              )
  let time = get_shader_global_time_phase(0.0, 0.0)
  let coef = saturate((time - swarm__emissionColor1.w) * swarm__emissionColor2.w)
  swarm__emissionColor1.xyz = lerp(swarm__emissionColor1.xyz, swarm__emissionColor2.xyz,
    float3(coef, coef, coef))
  swarm__emissionColor1.w = time
  swarm__emissionColor2.xyz = swarm__emissionColor
  swarm__emissionColor2.w = 1.0 / swarm__emissionChangeDuration

[es(on_appear, tag=render)]
def swarm_render_appear_color(
                              evt : Event;
                              swarm__emissionColor : float3;
                              var swarm__emissionColor1, swarm__emissionColor2 : float4&
                              )
  swarm__emissionColor1.xyz = swarm__emissionColor
  swarm__emissionColor1.w = -1.0
  swarm__emissionColor2.xyz = swarm__emissionColor
  swarm__emissionColor2.w = 1.0