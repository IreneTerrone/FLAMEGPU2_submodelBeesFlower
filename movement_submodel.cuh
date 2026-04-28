#ifndef MOVEMENT_SUBMODEL_H_
#define MOVEMENT_SUBMODEL_H_

#include "flamegpu/flamegpu.h"

using namespace flamegpu;

#define GRID_DIM 100

/**
 * 1. movingAgents broadcast their current position to mark cells as occupied.
 */
FLAMEGPU_AGENT_FUNCTION(movingAgent_broadcast_occupancy, MessageNone, MessageArray2D) {
    int x = FLAMEGPU->getVariable<int>("x");
    int y = FLAMEGPU->getVariable<int>("y");
    FLAMEGPU->message_out.setIndex(x, y);
    FLAMEGPU->message_out.setVariable<id_t>("occupant_id", FLAMEGPU->getID());
    return ALIVE;
}

/**
 * 2. movingAgents search neighborhood for empty cells and pick a random target.
 *    They output a move request to the target cell using Spatial Messaging
 *    to allow multiple movingAgents to request the same cell.
 */
FLAMEGPU_AGENT_FUNCTION(movingAgent_request_move, MessageArray2D, MessageSpatial2D) {
    if (FLAMEGPU->getVariable<int>("moved_this_step") == 1) {
        FLAMEGPU->setVariable<int>("target_x", -1);
        FLAMEGPU->setVariable<int>("target_y", -1);
    } else {
        int x = FLAMEGPU->getVariable<int>("x");
        int y = FLAMEGPU->getVariable<int>("y");

        int empty_count = 0;
        int empty_x[9];
        int empty_y[9];

        for (auto &msg : FLAMEGPU->message_in(x, y, 1)) {
            if (msg.getVariable<id_t>("occupant_id") == ID_NOT_SET) {
                empty_x[empty_count] = (int)msg.getX();
                empty_y[empty_count] = (int)msg.getY();
                empty_count++;
            }
        }

        if (empty_count > 0) {
            int choice = FLAMEGPU->random.uniform<int>(0, empty_count - 1);
            int tx = empty_x[choice];
            int ty = empty_y[choice];
            FLAMEGPU->setVariable<int>("target_x", tx);
            FLAMEGPU->setVariable<int>("target_y", ty);
            
            // Output request to spatial message
            FLAMEGPU->message_out.setVariable<id_t>("requester_id", FLAMEGPU->getID());
            FLAMEGPU->message_out.setVariable<float>("priority", FLAMEGPU->getVariable<float>("priority"));
            FLAMEGPU->message_out.setLocation((float)tx, (float)ty);
        } else {
            FLAMEGPU->setVariable<int>("target_x", -1);
            FLAMEGPU->setVariable<int>("target_y", -1);
        }
    }

    return ALIVE;
}

/**
 * 3. movingAgents check their target cell in the spatial message.
 *    If their priority is the highest among all requesters for that cell, they move.
 */
FLAMEGPU_AGENT_FUNCTION(movingAgent_execute_move, MessageSpatial2D, MessageNone) {
    id_t my_id = FLAMEGPU->getID();
    int tx = FLAMEGPU->getVariable<int>("target_x");
    int ty = FLAMEGPU->getVariable<int>("target_y");

    if (tx != -1 && ty != -1) {
        float my_priority = FLAMEGPU->getVariable<float>("priority");
        bool won = true;

        // Search the exact target location. Radius is set in define_message_submodule.
        for (auto &msg : FLAMEGPU->message_in((float)tx, (float)ty)) {
            float other_priority = msg.getVariable<float>("priority");
            if (other_priority > my_priority) {
                won = false;
                break;
            } else if (other_priority == my_priority) {
                // Tie breaker based on ID
                if (msg.getVariable<id_t>("requester_id") > my_id) {
                    won = false;
                    break;
                }
            }
        }

        if (won) {
            FLAMEGPU->setVariable<int>("x", tx);
            FLAMEGPU->setVariable<int>("y", ty);
            FLAMEGPU->setVariable<int>("moved_this_step", 1);
        }
    } 

    return ALIVE;
}

/**
 * Host Condition to allow multiple resolution passes
 */
FLAMEGPU_HOST_CONDITION(move_exit_condition) {
    static int iterations = 0;
    iterations++;
    // Corrected to use "active" state
    bool unresolved = FLAMEGPU->agent("movingAgent", "active").count<int>("moved_this_step", 0) > 0;
    if (unresolved && iterations < 5) {
        return CONTINUE;
    }
    iterations = 0;
    return EXIT;
}

/**
 * Init function to reset status
 */
FLAMEGPU_INIT_FUNCTION(reset_moved_this_step) {
    // Corrected to use "active" state
    auto movingAgents = FLAMEGPU->agent("movingAgent", "active");
    auto &agent_pop = movingAgents.getPopulationData();
    for (auto agent : agent_pop) {
        agent.setVariable<int>("moved_this_step", 0);
    }
}

void define_message_submodule(ModelDescription &smm) {
    auto m1 = smm.newMessage<MessageArray2D>("occupancy_status");
    m1.newVariable<id_t>("occupant_id");
    m1.setDimensions(GRID_DIM, GRID_DIM);

    auto m2 = smm.newMessage<MessageSpatial2D>("move_requests");
    m2.newVariable<id_t>("requester_id");
    m2.newVariable<float>("priority");
    m2.setMin(0, 0);
    m2.setMax(GRID_DIM, GRID_DIM);
    m2.setRadius(0.1f); // Search radius for target cell
}

void define_agent_submodule(ModelDescription &smm) {
    AgentDescription movingAgent = smm.newAgent("movingAgent");
    movingAgent.newState("active"); // Added state
    movingAgent.newVariable<int>("x");
    movingAgent.newVariable<int>("y");
    movingAgent.newVariable<float>("priority", 0.0f);
    movingAgent.newVariable<int>("target_x", -1);
    movingAgent.newVariable<int>("target_y", -1);
    movingAgent.newVariable<int>("moved_this_step", 0);

    auto f1 = movingAgent.newFunction("movingAgent_broadcast_occupancy", movingAgent_broadcast_occupancy);
    f1.setInitialState("active");
    f1.setEndState("active");
    f1.setMessageOutput("occupancy_status");
    
    auto f2 = movingAgent.newFunction("movingAgent_request_move", movingAgent_request_move);
    f2.setInitialState("active");
    f2.setEndState("active");
    f2.setMessageInput("occupancy_status");
    f2.setMessageOutput("move_requests");
    
    auto f3 = movingAgent.newFunction("movingAgent_execute_move", movingAgent_execute_move);
    f3.setInitialState("active");
    f3.setEndState("active");
    f3.setMessageInput("move_requests");
}

void define_layer_submodule(ModelDescription &smm) {
    smm.newLayer().addAgentFunction(movingAgent_broadcast_occupancy);
    smm.newLayer().addAgentFunction(movingAgent_request_move);
    smm.newLayer().addAgentFunction(movingAgent_execute_move);
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
    
    // Bind agent and map the 'active' state explicitly
    auto agent_map = smm.bindAgent("movingAgent", "movingAgent", true, false);
    agent_map.mapState("active", "active");

    return smm;
}

#endif
