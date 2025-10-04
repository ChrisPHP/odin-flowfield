package main

import "core:fmt"
import "core:thread"
import "core:time"
import "core:sync"

Task :: struct {
    id: int,
    goal: [2]int,
    cost_field: []f32,
    flow_field: []int,
    visual_field: []cstring
}

thread_worker :: proc(t: ^thread.Thread) {
    data := cast(^Task)t.data
    data.cost_field = calculate_flow_field(data.goal)
    data.flow_field, data.visual_field = generate_flow_vectors(data.cost_field)
}
