package main

import "core:slice"
import "core:fmt"
import rl "vendor:raylib"
import "core:mem"
import "core:math/rand"
import "core:math"
import "core:time"
import "core:thread"
import flowfield "flowfield"

tilemap := []int{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 1, 1, 0, 0, 0, 1, 1, 0,
    0, 1, 0, 0, 0, 0, 0, 0, 1, 0,
    0, 0, 0, 1, 1, 1, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 1, 0, 1, 1, 0,
    0, 1, 1, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 1, 1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 1, 0,
    0, 1, 0, 0, 0, 0, 0, 0, 1, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0
}
grid_width := 10
grid_height := 10
CELL_SIZE :: 64

main :: proc() {
    tracking_allocator: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking_allocator, context.allocator)
    defer mem.tracking_allocator_destroy(&tracking_allocator)
    context.allocator = mem.tracking_allocator(&tracking_allocator)
    defer {
        fmt.printfln("MEMORY SUMMARY")
        for _, leak in tracking_allocator.allocation_map {
            fmt.printfln(" %v leaked %m", leak.location, leak.size)
        }
        for bad_free in tracking_allocator.bad_free_array {
            fmt.printfln(" %v allocation %p was freed badly", bad_free.location, bad_free.memory)
        }
    }
 
    flowfield.flowfield_init(grid_width, grid_height)
    goal := [2]int{7,8}
    flow_fields := make([]flowfield.FlowField, 2)
    defer delete(flow_fields)

    THREAD_COUNT :: 2
    threads: [THREAD_COUNT]^thread.Thread
    thread_data: [THREAD_COUNT]Task


    rl.InitWindow(20 * CELL_SIZE, 10 * CELL_SIZE, "2D Grid")
    rl.SetTargetFPS(60)


    interval :f32= 0
    for !rl.WindowShouldClose() {
        if rl.IsKeyReleased(.R) {

            for i in 0..<THREAD_COUNT {
                delete(thread_data[i].cost_field)
                delete(thread_data[i].flow_field)
                delete(thread_data[i].visual_field)

                x := rand.int_max(9)
                y := rand.int_max(9)

                thread_data[i] = Task{
                    id = i,
                    goal = [2]int{x,y},
                    tilemap = tilemap,
                    allocator = context.allocator
                }

                threads[i] = thread.create(thread_worker)
                threads[i].data = &thread_data[i]
                thread.start(threads[i])
            }
        
        
            for t in threads {
                thread.join(t)
            }

            for data, index in thread_data {
                flow_fields[index].cost_field = data.cost_field
                flow_fields[index].flow_field = data.flow_field
                flow_fields[index].visual_field = data.visual_field
                fmt.printf("thread %d finished\n", data.id)
            }

            for t in threads {
                thread.destroy(t)
            }

        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)
        
        map_x := 0
        map_y := 0
        for field, index in flow_fields {
            if len(field.cost_field) == 0 {
                break
            }
            map_x = index*grid_width
            for i in 0..<grid_width {
                for j in 0..<grid_height {
                    x := i32(i * CELL_SIZE)
                    y := i32(j * CELL_SIZE)
                    size := j * grid_width + i
                
                    new_x := i32((map_x+i) * CELL_SIZE)
                    new_y := i32((map_y+j) * CELL_SIZE)
                
                    if tilemap[size] == 1 {
                        rl.DrawRectangle(new_x,new_y, CELL_SIZE, CELL_SIZE, rl.BLACK)
                    } else {          
                        val := field.cost_field[size]
                        arrow := field.visual_field[size]

                        lowered_val := val/10
                        colour := rl.ColorLerp(rl.Color{60, 255, 0, 255}, rl.Color{19, 79, 0, 255}, lowered_val)
                        text := fmt.ctprintf("%v", math.round_f32(val))
                        rl.DrawRectangle(new_x,new_y, CELL_SIZE,CELL_SIZE, colour)
                        rl.DrawText(text, new_x,new_y, 30, rl.WHITE)
                        
                    }
                    rl.DrawRectangleLines(new_x,new_y, CELL_SIZE, CELL_SIZE, rl.GRAY)
                }
            }
        }
        rl.EndDrawing()
    }
    rl.CloseWindow()

    for &field in flow_fields {
        delete(field.cost_field)
        delete(field.flow_field)
        delete(field.visual_field)
    }
}