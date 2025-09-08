options persistent_heap

require DagorShaders
require DagorMath
require ecs
require daFrameGraph.fg_ecs

struct Trajectory
  start, vel, gravity_dir : float3
  time, gravity, wideStart, wideEnd, colorGamma : float
  center, border : Color4

def render_grenade_trajectory(t : Trajectory)
  let numSegments = clamp(int(4. + t.time * 24.), 2, 512)
  query() <| $ [es] (trajectory_start_gravity : ShaderVar;
                     trajectory_gravity_dir : ShaderVar;
                     trajectory_vel_time : ShaderVar;
                     trajectory_center : ShaderVar;
                     trajectory_border : ShaderVar;
                     trajectory_total_thickness_gamma : ShaderVar)
    DagorShaders::set_color4(trajectory_start_gravity.varId, t.start, t.gravity)
    DagorShaders::set_color4(trajectory_gravity_dir.varId, t.gravity_dir, 0.0)
    DagorShaders::set_color4(trajectory_vel_time.varId, t.vel, t.time)
    DagorShaders::set_color4(trajectory_center.varId, t.center)
    DagorShaders::set_color4(trajectory_border.varId, t.border)
    DagorShaders::set_color4(trajectory_total_thickness_gamma.varId, float(numSegments), t.wideStart, t.wideEnd, t.colorGamma)
  d3d_draw(PRIM_TRISTRIP, 0, 2 * numSegments)

def render_grenade_trajectories()
  var statesSet = false
  query() <| $ [es] (trajectory__start : float3;
                     trajectory__vel : float3;
                     trajectory__time : float;
                     trajectory__enabled : bool;
                     trajectory__center : E3DCOLOR const?;
                     trajectory__border : E3DCOLOR const?;
                     trajectory__wide_start : float = 0.3;
                     trajectory__wide_end : float = 0.2;
                     trajectory__color_gamma : float = 8.;
                     trajectory__gravity : float = 9.81;
                     trajectory__gravity_dir : float3 = float3(0.0, -1.0, 0.0))
    let centerColor = Color4(trajectory__center ?? E3DCOLOR(0xFFFFFFFF))
    let borderColor = Color4(trajectory__border ?? E3DCOLOR(0x7F7FFFFF))
    if (!trajectory__enabled || (borderColor.a == 0.0 && centerColor.a == 0.0))
      return

    if (!statesSet)
      d3d_setvsrc(0, null, 0)
      query() <| $ [es] (trajectory_renderer_shader : ShadersECS)
        setStates(trajectory_renderer_shader)
      statesSet = true

    render_grenade_trajectory(Trajectory(
                                start = trajectory__start,
                                vel = trajectory__vel,
                                gravity_dir = trajectory__gravity_dir,
                                time = trajectory__time,
                                gravity = trajectory__gravity,
                                wideStart = trajectory__wide_start,
                                wideEnd = trajectory__wide_end,
                                colorGamma = trajectory__color_gamma,
                                center = centerColor,
                                border = borderColor))

def is_forward_render()
  return find_query() <| $ [es] (render_settings__forwardRendering : bool)
    return render_settings__forwardRendering

let grenade_trajectory_node_name = "grenade_trajectory_node"
let grenade_trajectory_node_entity = "grenade_trajectory_node"


[cpp_event(broadcast)]
struct OnRenderSettingsReady {}

[fg_ecs_node(on_event=OnRenderSettingsReady)]
def register_grenade_trajectory_node(var grenade_trajectory_node : NodeHandle&)
  grenade_trajectory_node <- root() |> registerNode(grenade_trajectory_node_name) <| @(var registry : Registry)
    if is_forward_render()
      registry |> read("depth_for_transparent_effects") |> texture |> atStage(Stage.POST_RASTER) |> bindToShaderVar("depth_gbuf")
      registry |> requestRenderPass |> color(fixed_array("target_after_transparent_scene_late"))
    else
      registry |> orderMeAfter("transparent_scene_late_node")
      registry |> read("far_downsampled_depth") |> texture |> atStage(Stage.POST_RASTER) |> bindToShaderVar("downsampled_far_depth_tex")
      registry |> requestRenderPass |> color(fixed_array("target_for_transparency"))
    return <- @ <|
      ecs::query() <| $ [es] (render_settings__forwardRendering : bool)
        if render_settings__forwardRendering
          DagorShaders::setBlock(-1, LAYER_FRAME)

      render_grenade_trajectories()

