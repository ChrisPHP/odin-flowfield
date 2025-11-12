package main

import "base:runtime"
import "core:fmt"
import "core:thread"
import "core:time"
import "core:sync"
import "core:mem"

import flowfield "flowfield"

Task :: struct {
    id: int,
    goal: [2]int,
    tilemap: []int,
    cost_field: []f32,
    flow_field: []int,
    visual_field: []cstring,
    allocator: mem.Allocator
}


thread_worker :: proc(t: ^thread.Thread) {
    data := cast(^Task)t.data
    context.allocator = data.allocator

    data.cost_field = flowfield.calculate_flow_field(data.goal, data.tilemap)
    data.flow_field, data.visual_field = flowfield.generate_flow_vectors(data.cost_field, data.tilemap)
}
