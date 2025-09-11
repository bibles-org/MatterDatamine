module thermal_vision_event shared
require ecs

[cpp_event(unicast)]
struct OnChangeThermalActivePreset{}
