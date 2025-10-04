package main

import "core:slice"
import "core:fmt"
import rl "vendor:raylib"
import "core:mem"
import "core:math/rand"
import "core:math"
import pq "core:container/priority_queue"
import "core:time"
import "core:thread"

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

PathNode :: struct {
    cost: f32,
    x: int,
    y: int
}

FlowField :: struct {
    cost_field: []f32,
    flow_field: []int,
    visual_field: []cstring
}

node_cost :: proc(a, b: ^PathNode) -> bool {
    return a.cost < b.cost
}

new_node :: proc(x,y: int, cost: f32) -> ^PathNode {
    new_node := new(PathNode)
    new_node.x = x
    new_node.y = y
    new_node.cost = cost
    return new_node
}

calculate_flow_field :: proc(goal: [2]int) -> []f32 {

    pos_check := goal[1] * grid_width + goal[0]
    if tilemap[pos_check] == 1 {
        return {}
    }
    cost_field := make([]f32, grid_width*grid_height)
    for &i in cost_field {
        i = 10000000
    }
    g_x := goal[0]
    g_y := goal[1]

    goal_pos := g_y * grid_width + g_x

    cost_field[goal_pos] = 0

    pqueue: pq.Priority_Queue(^PathNode)
    pq.init(&pqueue, node_cost, pq.default_swap_proc(^PathNode))
    d_node := new_node(g_x, g_y, 0)
    pq.push(&pqueue, d_node)

    visited := make([]bool, grid_width*grid_height)
    defer delete(visited)

    for pq.len(pqueue) > 0 {
        node :=  pq.pop(&pqueue)

        grid_pos := node.y * grid_width + node.x

        if visited[grid_pos] {
            free(node)
            continue
        }
        visited[grid_pos] = true

        directions := [8][2]int{{-1,0}, {1,0}, {0,-1}, {0,1},
                                {-1,-1}, {-1,1}, {1,-1}, {1,1}}
        for pos in directions {
            dx := pos[0]
            dy := pos[1]

            nx := node.x + dx
            ny := node.y + dy
            new_grid_pos := ny * grid_width + nx
            if nx > grid_width-1 || nx < 0 || ny > grid_height-1 || ny < 0 {
                continue
            }

            if tilemap[new_grid_pos] == 1 {
                continue
            }

            move_cost := math.sqrt_f32(f32(dx*dx) + f32(dy*dy))
            new_cost := node.cost + move_cost

            if new_cost < cost_field[new_grid_pos] {
                cost_field[new_grid_pos] = new_cost
                d_node = new_node(nx, ny, new_cost)
                pq.push(&pqueue, d_node)
            }
        }
        free(node)
    }
    pq.destroy(&pqueue)

    return cost_field
}

generate_flow_vectors :: proc(cost_field: []f32) -> ([]int, []cstring) {
    if len(cost_field) == 0 {
        return {}, {}
    }
    flow_field := make([]int, grid_width*grid_height)
    visual_field := make([]cstring, grid_width*grid_height)
    for i in 0..<grid_width {
        for j in 0..<grid_height {
            size := j * grid_width + i
            if tilemap[size] == 1 {
                continue
            }

            best_dir := 0
            arrow_dir :cstring= ""
            best_cost := cost_field[size]

            directions := [8][2]int{{-1,0}, {1,0}, {0,-1}, {0,1},
                                {-1,-1}, {-1,1}, {1,-1}, {1,1}}
            arrow_direction := [8]cstring{"←","→","↑", "↓", "↖", "↙", "↗", "↘"}
            for pos, index in directions {
                dx := pos[0]
                dy := pos[1]

                nx := i + dx
                ny := j + dy
                new_grid_pos := ny * grid_width + nx

                if nx > grid_width-1 || nx < 0 || ny > grid_height-1 || ny < 0 {
                    continue
                }

                if cost_field[new_grid_pos] < best_cost {
                    best_cost = cost_field[new_grid_pos]
                    best_dir = new_grid_pos
                    arrow_dir = arrow_direction[index]
                }
            }
            flow_field[size] = best_dir
            visual_field[size] = arrow_dir
        }
    }

    return flow_field, visual_field
}

round_decimal :: proc(a, b: f32) -> f32 {
    multiplier := math.pow_f32(10.0, b)
    rounded := math.round_f32(a * multiplier) / multiplier
    return rounded
}

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
 
    goal := [2]int{7,8}
    flow_fields := make([]FlowField, 2)
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
                x := rand.int_max(9)
                y := rand.int_max(9)

                thread_data[i] = Task{
                    id = i,
                    goal = [2]int{x,y}
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

        //rl.DrawFPS(10,10)
        rl.EndDrawing()
    }
    rl.CloseWindow()
}