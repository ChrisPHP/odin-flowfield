package FlowField

import pq "core:container/priority_queue"
import "core:math"

GRID_WIDTH := 0
GRID_HEIGHT := 0

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

calculate_flow_field :: proc(goal: [2]int, tilemap: []int) -> []f32 {

    pos_check := goal[1] * GRID_WIDTH + goal[0]
    if tilemap[pos_check] == 1 {
        return {}
    }
    cost_field := make([]f32, GRID_WIDTH*GRID_HEIGHT)
    for &i in cost_field {
        i = 10000000
    }
    g_x := goal[0]
    g_y := goal[1]

    goal_pos := g_y * GRID_WIDTH + g_x

    cost_field[goal_pos] = 0

    pqueue: pq.Priority_Queue(^PathNode)
    pq.init(&pqueue, node_cost, pq.default_swap_proc(^PathNode))
    d_node := new_node(g_x, g_y, 0)
    pq.push(&pqueue, d_node)

    visited := make([]bool, GRID_WIDTH*GRID_HEIGHT)
    defer delete(visited)

    for pq.len(pqueue) > 0 {
        node :=  pq.pop(&pqueue)

        grid_pos := node.y * GRID_WIDTH + node.x

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
            new_grid_pos := ny * GRID_WIDTH + nx
            if nx > GRID_WIDTH-1 || nx < 0 || ny > GRID_HEIGHT-1 || ny < 0 {
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

generate_flow_vectors :: proc(cost_field: []f32, tilemap: []int) -> ([]int, []cstring) {
    if len(cost_field) == 0 {
        return {}, {}
    }
    flow_field := make([]int, GRID_WIDTH*GRID_HEIGHT)
    visual_field := make([]cstring, GRID_WIDTH*GRID_HEIGHT)
    for i in 0..<GRID_WIDTH {
        for j in 0..<GRID_HEIGHT {
            size := j * GRID_WIDTH + i
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
                new_grid_pos := ny * GRID_WIDTH + nx

                if nx > GRID_WIDTH-1 || nx < 0 || ny > GRID_HEIGHT-1 || ny < 0 {
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

flowfield_init :: proc(width, height: int) {
    GRID_WIDTH = width
    GRID_HEIGHT = height
}