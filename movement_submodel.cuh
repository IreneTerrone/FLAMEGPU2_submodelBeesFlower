#ifndef MOVEMENT_SUBMODEL_H_
#define MOVEMENT_SUBMODEL_H_

#include "flamegpu/flamegpu.h"

using namespace flamegpu;

#define GRID_DIM 100

/**
 * 1. Cells output their status (nectar, occupancy)
 */
FLAMEGPU_AGENT_FUNCTION(cell_output_status, MessageNone, MessageArray2D) {
    int x = FLAMEGPU->getVariable<int>("x");
    int y = FLAMEGPU->getVariable<int>("y");
    FLAMEGPU->message_out.setIndex(x, y);
    FLAMEGPU->message_out.setVariable<int>("is_occupied", FLAMEGPU->getVariable<int>("is_occupied"));
    FLAMEGPU->message_out.setVariable<float>("nectar", FLAMEGPU->getVariable<float>("nectar"));
    return ALIVE;
}

/**
 * 2. Bees search neighborhood for max nectar and output request
 */
FLAMEGPU_AGENT_FUNCTION(bee_request_move, MessageArray2D, MessageArray2D) {
    // Only request if not already moved and not currently at a flower
    if (FLAMEGPU->getVariable<int>("moved_this_step") == 1 || 
        FLAMEGPU->getVariable<int>("is_at_flower") == 1) {
        FLAMEGPU->setVariable<int>("target_x", -1);
        FLAMEGPU->setVariable<int>("target_y", -1);
    } else {
        int x = FLAMEGPU->getVariable<int>("x");
        int y = FLAMEGPU->getVariable<int>("y");
        int lx = FLAMEGPU->getVariable<int>("last_x");
        int ly = FLAMEGPU->getVariable<int>("last_y");
        int lfx = FLAMEGPU->getVariable<int>("last_flower_x");
        int lfy = FLAMEGPU->getVariable<int>("last_flower_y");
        
        float max_nectar = -1.0f;
        float max_tie_breaker = -1.0f;
        int target_x = -1;
        int target_y = -1;
        int target_has_nectar = 0;

        for (auto &msg : FLAMEGPU->message_in(x, y, 1)) {
            int mx = (int)msg.getX();
            int my = (int)msg.getY();

            // Only consider unoccupied cells (that aren't where we just came from)
            if (msg.getVariable<int>("is_occupied") == 0 && !(mx == lx && my == ly)) {
                float n = msg.getVariable<float>("nectar");
                float tie_breaker = FLAMEGPU->random.uniform<float>();
                
                if (n > max_nectar || (n == max_nectar && tie_breaker > max_tie_breaker)) {
                    // Check coordinate-based identity of the last flower
                    if (!(mx == lfx && my == lfy)) {
                        max_nectar = n;
                        max_tie_breaker = tie_breaker;
                        target_x = mx;
                        target_y = my;
                        target_has_nectar = (n > 0.0f) ? 1 : 0;
                    }
                }
            }
        }

        FLAMEGPU->setVariable<int>("target_x", target_x);
        FLAMEGPU->setVariable<int>("target_y", target_y);
        FLAMEGPU->setVariable<int>("target_has_nectar", target_has_nectar);
    }

    // Always output a message to keep the MessageArray2D dense
    FLAMEGPU->message_out.setIndex(FLAMEGPU->getVariable<int>("x"), FLAMEGPU->getVariable<int>("y"));
    FLAMEGPU->message_out.setVariable<id_t>("bee_id", FLAMEGPU->getID());
    FLAMEGPU->message_out.setVariable<int>("target_x", FLAMEGPU->getVariable<int>("target_x"));
    FLAMEGPU->message_out.setVariable<int>("target_y", FLAMEGPU->getVariable<int>("target_y"));
    FLAMEGPU->message_out.setVariable<float>("priority", FLAMEGPU->getVariable<float>("priority"));

    return ALIVE;
}

/**
 * 3. Cells check neighbors for bees requesting them and pick the winner
 */
FLAMEGPU_AGENT_FUNCTION(cell_resolve_conflict, MessageArray2D, MessageArray2D) {
    int x = FLAMEGPU->getVariable<int>("x");
    int y = FLAMEGPU->getVariable<int>("y");

    id_t winner_id = ID_NOT_SET;
    float max_p = -1.0f;
    float max_tie_breaker = -1.0f;

    // Only resolve if currently unoccupied
    if (FLAMEGPU->getVariable<int>("is_occupied") == 0) {
        for (auto &msg : FLAMEGPU->message_in(x, y, 1)) {
            // Match target coordinates instead of ID
            if (msg.getVariable<int>("target_x") == x && msg.getVariable<int>("target_y") == y) {
                float p = msg.getVariable<float>("priority");                         
                float tie_breaker = FLAMEGPU->random.uniform<float>();
                
                if (p > max_p || (p == max_p && tie_breaker > max_tie_breaker)) {
                    max_p = p;
                    max_tie_breaker = tie_breaker;
                    winner_id = msg.getVariable<id_t>("bee_id");
                }
            }
        }
    }

    FLAMEGPU->message_out.setIndex(x, y);
    FLAMEGPU->message_out.setVariable<id_t>("winner_id", winner_id);

    return ALIVE;
}

/**
 * 4. Bees check if they won and update coordinates
 */
FLAMEGPU_AGENT_FUNCTION(bee_execute_move, MessageArray2D, MessageArray2D) {
    id_t my_id = FLAMEGPU->getID();
    int tx = FLAMEGPU->getVariable<int>("target_x");
    int ty = FLAMEGPU->getVariable<int>("target_y");

    if (tx != -1 && ty != -1) {
        auto msg = FLAMEGPU->message_in.at(tx, ty);
        if (msg.getVariable<id_t>("winner_id") == my_id) {
            FLAMEGPU->setVariable<int>("last_x", FLAMEGPU->getVariable<int>("x"));
            FLAMEGPU->setVariable<int>("last_y", FLAMEGPU->getVariable<int>("y"));
            FLAMEGPU->setVariable<int>("x", tx);
            FLAMEGPU->setVariable<int>("y", ty);
            
            // If the cell we moved to has nectar, it becomes our last flower
            if (FLAMEGPU->getVariable<int>("target_has_nectar") == 1) {
                FLAMEGPU->setVariable<int>("last_flower_x", tx);
                FLAMEGPU->setVariable<int>("last_flower_y", ty);
                FLAMEGPU->setVariable<int>("is_at_flower", 1);
            } else {
                FLAMEGPU->setVariable<int>("is_at_flower", 0);
            }
            FLAMEGPU->setVariable<int>("moved_this_step", 1);
        }
    } 

    // Notify current location of presence
    FLAMEGPU->message_out.setIndex(FLAMEGPU->getVariable<int>("x"), FLAMEGPU->getVariable<int>("y"));
    FLAMEGPU->message_out.setVariable<id_t>("bee_id", my_id);

    return ALIVE;
}

/**
 * 5. Cells update occupancy based on bee locations
 */
FLAMEGPU_AGENT_FUNCTION(cell_update_occupancy, MessageArray2D, MessageNone) {
    int x = FLAMEGPU->getVariable<int>("x");
    int y = FLAMEGPU->getVariable<int>("y");
    auto msg = FLAMEGPU->message_in.at(x, y);
    FLAMEGPU->setVariable<int>("is_occupied", (msg.getVariable<id_t>("bee_id") != ID_NOT_SET) ? 1 : 0);
    return ALIVE;
}

/**
 * Host Condition to allow multiple resolution passes
 */
FLAMEGPU_HOST_CONDITION(move_exit_condition) {
    static int iterations = 0;
    iterations++;
    // Continue if there are bees not at flowers that haven't moved yet
    bool unresolved = FLAMEGPU->agent("bee").count<int>("moved_this_step", 0) > 0;
    // Cap at 5 iterations to prevent infinite loops in crowded areas
    if (unresolved && iterations < 5) {
        return CONTINUE;
    }
    iterations = 0;
    return EXIT;
}

/**
 * Init function for the submodel to reset movement status
 */
FLAMEGPU_INIT_FUNCTION(reset_moved_this_step) {
    auto bees = FLAMEGPU->agent("bee");
    auto &bee_pop = bees.getPopulationData();
    for (auto bee : bee_pop) {
        bee.setVariable<int>("moved_this_step", 0);
    }
}

void define_message_submodule(ModelDescription &smm) {
    auto m1 = smm.newMessage<MessageArray2D>("cell_status");
    m1.newVariable<int>("is_occupied");
    m1.newVariable<float>("nectar");
    m1.setDimensions(GRID_DIM, GRID_DIM);

    auto m2 = smm.newMessage<MessageArray2D>("move_request");
    m2.newVariable<id_t>("bee_id");
    m2.newVariable<int>("target_x");
    m2.newVariable<int>("target_y");
    m2.newVariable<float>("priority");
    m2.setDimensions(GRID_DIM, GRID_DIM);

    auto m3 = smm.newMessage<MessageArray2D>("move_response");
    m3.newVariable<id_t>("winner_id");
    m3.setDimensions(GRID_DIM, GRID_DIM);

    auto m4 = smm.newMessage<MessageArray2D>("bee_location");
    m4.newVariable<id_t>("bee_id");
    m4.setDimensions(GRID_DIM, GRID_DIM);
}

void define_agent_submodule(ModelDescription &smm) {
    AgentDescription cell = smm.newAgent("cell");
    cell.newVariable<int>("x");
    cell.newVariable<int>("y");
    cell.newVariable<int>("is_occupied", 0);
    cell.newVariable<float>("nectar", 0.0f);

    AgentDescription bee = smm.newAgent("bee");
    bee.newVariable<int>("x");
    bee.newVariable<int>("y");
    bee.newVariable<int>("last_x", -1);
    bee.newVariable<int>("last_y", -1);
    bee.newVariable<float>("priority", 0.0f);
    bee.newVariable<int>("target_x", -1);
    bee.newVariable<int>("target_y", -1);
    bee.newVariable<int>("last_flower_x", -1);
    bee.newVariable<int>("last_flower_y", -1);
    bee.newVariable<int>("is_at_flower", 0);
    bee.newVariable<int>("target_has_nectar", 0);
    bee.newVariable<int>("moved_this_step", 0);

    auto f1 = cell.newFunction("cell_output_status", cell_output_status);
    f1.setMessageOutput("cell_status");
    
    auto f2 = cell.newFunction("cell_resolve_conflict", cell_resolve_conflict);
    f2.setMessageInput("move_request");
    f2.setMessageOutput("move_response");
    
    auto f3 = cell.newFunction("cell_update_occupancy", cell_update_occupancy);
    f3.setMessageInput("bee_location");

    auto f4 = bee.newFunction("bee_request_move", bee_request_move);
    f4.setMessageInput("cell_status");
    f4.setMessageOutput("move_request");
    
    auto f5 = bee.newFunction("bee_execute_move", bee_execute_move);
    f5.setMessageInput("move_response");
    f5.setMessageOutput("bee_location");
}

void define_layer_submodule(ModelDescription &smm) {
    smm.newLayer().addAgentFunction(cell_output_status);
    smm.newLayer().addAgentFunction(bee_request_move);
    smm.newLayer().addAgentFunction(cell_resolve_conflict);
    smm.newLayer().addAgentFunction(bee_execute_move);
    smm.newLayer().addAgentFunction(cell_update_occupancy);
}

SubModelDescription add_movement_submodel(ModelDescription &model) {
    ModelDescription sub_model_move("movement_submodel");
    define_message_submodule(sub_model_move);
    define_agent_submodule(sub_model_move);
    define_layer_submodule(sub_model_move);
    sub_model_move.addExitCondition(move_exit_condition);
    sub_model_move.addInitFunction(reset_moved_this_step);

    SubModelDescription smm = model.newSubModel("move", sub_model_move);
    smm.setMaxSteps(5); 
    smm.bindAgent("bee", "bee", true, true);
    smm.bindAgent("cell", "cell", true, true);

    return smm;
}

#endif
