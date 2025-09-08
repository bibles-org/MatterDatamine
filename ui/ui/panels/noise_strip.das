options no_global_variables = false

require app
require DagorMath
require DagorRandom
require DagorStdGuiRender
require darg
require math


let dashCount = 37
let maxLoudness = 160.0

let neutralColor = E3DCOLOR(Color4(float4(0.8, 0.8, 0.8, 0.8))) // rgba(204,204,204,0.8)

let gradientColors <- fixed_array<E3DCOLOR>(
  neutralColor,
  E3DCOLOR(Color4(float4(0.53, 0.74, 0.89, 0.8))),   // rgba(135,189,228,0.8)
  E3DCOLOR(Color4(float4(0.93, 0.92, 0.59, 0.8))),   // rgba(237,235,151,0.8)
  E3DCOLOR(Color4(float4(0.96, 0.73, 0.45, 0.8))),   // rgba(244,186,116,0.8)
  E3DCOLOR(Color4(float4(0.6, 0.16, 0.16, 1.0)))     // rgba(153,40,40,1)
)

var prevUpdateAt = 0.0
let noiseUpdateInterval = 0.1
var noiseUpdateAt = 0.0

// idk how to init these arrays in a better way.
var noiseArray <- fixed_array<float>(
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

var speechWaves <- fixed_array<float>(
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

var wishScale <- fixed_array<float>(
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

var currentScale <- fixed_array<float>(
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

struct WatchCircleParams
  loudness : float = 0.0
  speech : bool = false

struct VoiceWave
  amplitude : float
  pos : int
  speed : int
  width : int

var voiceWaves <- fixed_array(
    VoiceWave(amplitude = 1.0, pos = 0, speed = 3, width = 5),
    VoiceWave(amplitude = 1.0, pos = 15, speed = 3, width = 6),
    VoiceWave(amplitude = 1.0, pos = 30, speed = 3, width = 5),
    VoiceWave(amplitude = 1.0, pos = 45, speed = 3, width = 8))

[export]
def setup_data(props : Properties&; var storage : WatchCircleParams&)
  storage.loudness = props |> getFloat("loudness", 0.0)
  storage.speech = props |> getBool("speech", false)

var seed = 42

[export, unused_argument(rstate)]
def draw_noise_strip(var ctx : GuiContext&;
                     rdata : ElemRenderData& const;
                     rstate : RenderState& const;
                     data : WatchCircleParams& const)
  let curTime = get_sync_time()
  if curTime < prevUpdateAt
    prevUpdateAt = 0.0
    noiseUpdateAt = 0.0

  let correctedLoudness = clamp(sqrt(data.loudness / maxLoudness), 0.0, 1.0)

  if curTime > noiseUpdateAt
    noiseUpdateAt = curTime + noiseUpdateInterval
    for i in range(0, dashCount)
      noiseArray[i] = _frnd(seed) * 0.6 - 0.3
      speechWaves[i] = data.speech ? 0.2 : 0.0
    var pos = 0
    if data.speech
      for wave in voiceWaves
        for i in range(0, wave.width)
          pos = (dashCount + wave.pos - (wave.width / 2) + i) % dashCount
        wave.pos = (wave.pos + wave.speed) % dashCount

  for i in range(0, dashCount)
    wishScale[i] = clamp(0.2 + correctedLoudness * 0.8 + noiseArray[i] * correctedLoudness + speechWaves[i], 0.0, 1.0)

  let t = 1.0 - exp(-8.0 * (curTime - prevUpdateAt))
  for i in range(0, dashCount)
    currentScale[i] += t * (wishScale[i] - currentScale[i])

  let startX = rdata.pos.x
  let centerY = (rdata.pos.y + rdata.size.y) * 0.5

  for s, idx in currentScale, range(currentScale |> length())
    let islong = idx % 9 == 0
    let width = islong ? 3.0 : 2.0
    let dash = islong ? 15.0 : 10.0
    let x0 = startX + float(idx) / float(dashCount - 1) * (rdata.size.x)
    let y0 = centerY - 10.0
    let y1 = y0 - dash * s

    let colorIdx = clamp(int(s * 4.99), 0, 4)
    let color = islong ? gradientColors[colorIdx] : neutralColor

    ctx |> set_color(color)
    let coord <- to_array_move(fixed_array(float2(x0, y0), float2(x0, y1)))
    ctx |> render_line_aa(coord, false, width, float2(0, 0), color)

  prevUpdateAt = curTime

