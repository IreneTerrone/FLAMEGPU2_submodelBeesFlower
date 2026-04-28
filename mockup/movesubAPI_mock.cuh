#include "flamegpu/flamegpu.h"
#include <iostream>
#include <map>
#include <string>
#include <vector>

namespace Stock {
namespace SubModels {

/**
 * Wrapper for a SubModel that allows delayed agent mapping, auto-mapping, and state mapping.
 */
class SubModelWrapper {
public:
    SubModelWrapper(flamegpu::SubModelDescription _smm) : smm(_smm) {}

    /**
     * Maps an internal submodel agent to a parent model agent.
     * @param internal_name The name of the agent inside the submodel.
     * @param parent_name The name of the agent in the parent model.
     * @param var_map Map of {internal_variable_name, parent_variable_name}.
     * @param state_map Map of {internal_state_name, parent_state_name}.
     * @param auto_map If true, variables/states with matching names are mapped automatically.
     */
    void setAgent(SubModelDescription &smm,
                  const std::string& internal_name, 
                  const std::string& parent_name,
                  const std::map<std::string, std::string>& var_map = {},
                  const std::map<std::string, std::string>& state_map = {},
                  bool auto_map = false) {
        
        // bindAgent(internal, parent, auto_map_vars, auto_map_states)
        auto agent_map = smm.bindAgent(internal_name, parent_name, auto_map, auto_map);
        
        // Explicitly map variables
        for (auto const& [internal_var, parent_var] : var_map) {
            agent_map.mapVariable(internal_var, parent_var);
        }

        // Explicitly map states
        for (auto const& [internal_state, parent_state] : state_map) {
            agent_map.mapState(internal_state, parent_state);
        }
    }

    operator flamegpu::SubModelDescription&() { return smm; }

private:
    flamegpu::SubModelDescription smm;
};

// --- Movement Submodel Logic ---

FLAMEGPU_AGENT_FUNCTION(agent_request_move, flamegpu::MessageNone, flamegpu::MessageArray2D) {
    // This function only runs for agents in the state it was assigned to
    return flamegpu::ALIVE;
}

FLAMEGPU_AGENT_FUNCTION(agent_execute_move, flamegpu::MessageArray2D, flamegpu::MessageNone) {
    return flamegpu::ALIVE;
}

FLAMEGPU_HOST_CONDITION(move_exit_condition) {
    return flamegpu::EXIT;
}

inline SubModelWrapper Movement(flamegpu::ModelDescription& parent) {
    flamegpu::ModelDescription sub("movement_submodel");
    
    // Internal Agent Definition with States
    flamegpu::AgentDescription agent = sub.newAgent("movingAgent");
    agent.newState("active");    // participing in movement
    agent.newState("stationary"); // not participating
    
    agent.newVariable<int>("x");
    agent.newVariable<int>("y");
    agent.newVariable<float>("priority");
    agent.newVariable<int>("target_x");
    agent.newVariable<int>("target_y");
    agent.newVariable<int>("moved_this_step");

    auto msg = sub.newMessage<flamegpu::MessageArray2D>("move_requests");
    msg.setDimensions(100, 100);

    // Assign functions to the "active" state
    auto f1 = agent.newFunction("agent_request_move", agent_request_move);
    f1.setInitialState("active");
    f1.setEndState("active");
    f1.setMessageOutput("move_requests");
    
    auto f2 = agent.newFunction("agent_execute_move", agent_execute_move);
    f2.setInitialState("active");
    f2.setEndState("active");
    f2.setMessageInput("move_requests");

    sub.newLayer().addAgentFunction(f1);
    sub.newLayer().addAgentFunction(f2);
    sub.addExitCondition(move_exit_condition);

    auto smm = parent.newSubModel("MovementInstance", sub);
    smm.setMaxSteps(5);
    
    return SubModelWrapper(smm);
}

} // namespace SubModels
} // namespace Stock
