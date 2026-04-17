#include "flamegpu/flamegpu.h"
#include <iostream>
#include <fstream>


namespace MovementAPI {

const char* INTERNAL_AGENT = "MovingAgent";
const char* INTERNAL_CELL = "GridCell";

FLAMEGPU_AGENT_FUNCTION(cell_output_status, MessageNone, MessageArray2D) {

        ...
}

/**
 * 2. Bees search neighborhood for max nectar and output request
 */
FLAMEGPU_AGENT_FUNCTION(agent_request_move, MessageArray2D, MessageArray2D) {
    
    ...
}

/**
 * 3. Cells check neighbors for bees requesting them and pick the winner
 */
FLAMEGPU_AGENT_FUNCTION(cell_resolve_conflict, MessageArray2D, MessageArray2D) {
    ...
}

/**
 * 4. Bees check if they won and update coordinates
 */
FLAMEGPU_AGENT_FUNCTION(agent_execute_move, MessageArray2D, MessageArray2D) {
    ...
}

/**
 * 5. Cells update occupancy based on bee locations
 */
FLAMEGPU_AGENT_FUNCTION(cell_update_occupancy, MessageArray2D, MessageNone) {
    ...
}

/**
 * Host Condition to allow multiple resolution passes
 */
FLAMEGPU_HOST_CONDITION(move_exit_condition) {
    static int iterations = 0;
    iterations++;
    // Continue if there are bees not at flowers that haven't moved yet
    bool unresolved = FLAMEGPU->agent("movingAgent").count<int>("moved_this_step", 0) > 0;
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
    auto movingAgent = FLAMEGPU->agent("movingAgent");
    auto &agent_pop = movingAgent.getPopulationData();
    for (auto agent : agent_pop) {
        agent.setVariable<int>("moved_this_step", 0);
    }
}

//defining messages useg by submodule
void define_message_submodule(ModelDescription &smm, int dimX, int dimY) {
    auto m1 = smm.newMessage<MessageArray2D>("cell_status");
    m1.newVariable<int>("is_occupied");
    m1.newVariable<float>("nectar");
    m1.setDimensions(dimX, dimY);

    auto m2 = smm.newMessage<MessageArray2D>("move_request");
    m2.newVariable<id_t>("bee_id");
    m2.newVariable<int>("target_x");
    m2.newVariable<int>("target_y");
    m2.newVariable<float>("priority");
    m2.setDimensions(dimX, dimY);

    auto m3 = smm.newMessage<MessageArray2D>("move_response");
    m3.newVariable<id_t>("winner_id");
    m3.setDimensions(dimX, dimY);

    auto m4 = smm.newMessage<MessageArray2D>("bee_location");
    m4.newVariable<id_t>("bee_id");
    m4.setDimensions(dimX, dimY);
}


define_internal_agents_submodule(ModelDescription &smm) {
    AgentDescription movingAgent = smm.newAgent(INTERNAL_AGENT);
    movingAgent.newVariable<int>("x");
    movingAgent.newVariable<int>("y");
    movingAgent.newVariable<int>("target_x", -1);
    movingAgent.newVariable<int>("target_y", -1);
    movingAgent.newVariable<float>("priority_sub", 0.0f); //mapped from priority_main
    movingAgent.newVariable<int>("moved_this_step", 0);

    AgentDescription gridCell = smm.newAgent(INTERNAL_CELL);
    gridCell.newVariable<int>("x");
    gridCell.newVariable<int>("y");
    gridCell.newVariable<int>("is_occupied", 0);
    gridCell.newVariable<float>("nectar_sub", 0.0f);

    //mapping functionss
    auto f1 = cell.newFunction("cell_output_status", cell_output_status);
    f1.setMessageOutput("cell_status");
    
    auto f2 = cell.newFunction("cell_resolve_conflict", cell_resolve_conflict);
    f2.setMessageInput("move_request");
    f2.setMessageOutput("move_response");
    ...
}


//define layers
void define_layer_submodule(ModelDescription &smm) {
    smm.newLayer().addAgentFunction(cell_output_status);
    smm.newLayer().addAgentFunction(bee_request_move);
    smm.newLayer().addAgentFunction(cell_resolve_conflict);
    smm.newLayer().addAgentFunction(bee_execute_move);
    smm.newLayer().addAgentFunction(cell_update_occupancy);
}


void map_variables(SubModelDescription &smm,
                    string parentMovingAgentName,
                    string parentCellName,
                    const vector<string>& REQUIRED_VARS_MOVING_AGENT, 
                    const vector<string>& REQUIRED_VARS_CELL_AGENT, 
                    const map<string, string>& agentMap, 
                    const map<string, string>& cellMap) {

     // Bind to parent model agents
    SubAgentDescription agent_map = smm.bindAgent(INTERNAL_AGENT, parentMovingAgentName, false, false);
    SubAgentDescription cell_map = smm.bindAgent(INTERNAL_CELL, parentCellName, false, false);

    for (const string& var : REQUIRED_VARS_MOVING_AGENT) {
                // 1. If user provided a custom name in the map, use it
        if (agentMap.count(var)) {
            agent_map.mapVariable(var, agentMap[var]);
        } 
        // 2. Otherwise, assume the parent name is the same as the internal name
        else {
            agent_map.mapVariable(var, var); 
        }
    }

    for (const string& var : REQUIRED_VARS_CELL_AGENT) {
        if (cellMap.count(var)) {
            cell_map.mapVariable(var, cellMap[var]);
        } else {
            cell_map.mapVariable(var, var); 
        }
    }
    
}

SubModelDescription setup(ModelDescription &parent, 
                        std::string parentMovingAgentName, 
                        std::string parentCellName,
                        int dimX, int dimY,
                        map<string, string> agentMap = {},
                        map<string, string> cellMap = {}) {
            
            ModelDescription sub("movement_submodel");
            
            // Define internal submodel agents/messages
            // Use generic names like "MovingAgent" and "GridCell"
            define_internal_agents_submodule(sub);
            define_message_submodule(sub, dimX, dimY);
            define_layer_submodule(sub);
            sub.addInitFunction(reset_submodel_state);
            sub.addExitCondition(move_exit_condition);
        
            // Create the SubModel linkage
            auto smm = parent.newSubModel("movement", sub);
            smm.setMaxSteps(5); 


            const vector<string> REQUIRED_VARS_MOVING_AGENT = {"x", "y", "priority", "target_x", "target_y".........};
            const vector<string> REQUIRED_VARS_CELL_AGENT = {"x", "y", "is_occupied", "nectar".........};
            
            // Map variables with flexibility for user-defined names
            map_variables(Submodel REQUIRED_VARS_MOVING_AGENT, REQUIRED_VARS_CELL_AGENT, agentMap, cellMap);
            
   
            return smm;
        }
    

}