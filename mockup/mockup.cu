#include <iostream>
#include <fstream>
#include "flamegpu/flamegpu.h"
#include "host_function.cuh"
#include "agent_functions.cuh"
#include "movesubAPI_mock.cuh"





void define_model(ModelDescription &model) {
    //all variables here must be defined to be passed also to the submodel except hunger and wait
    //we could gibe more general name, like not nectar but resource
    //about last flower x and y we could decide the rules for submodel.

      // Cell Agent
    AgentDescription cell = model.newAgent("cell");
    cell.newVariable<int>("x");
    cell.newVariable<int>("y");
    cell.newVariable<int>("is_occupied", 0);
    cell.newVariable<float>("nectar", 0.0f);

    // Bee Agent
    AgentDescription bee = model.newAgent("bee");
    bee.newVariable<int>("x");
    bee.newVariable<int>("y");
    bee.newVariable<int>("last_x", -1);
    bee.newVariable<int>("last_y", -1);
  //  bee.newVariable<float>("hunger_level"); //these are only variable for the agent to calculate priority, they are not used in the movement submodel
   // bee.newVariable<int>("wait", 0); //these are only variable for the agent to calculate priority, they are not used in the movement submodel
    bee.newVariable<float>("priority_main", 0.0f); 
    bee.newVariable<int>("target_x", -1);
    bee.newVariable<int>("target_y", -1);
    bee.newVariable<int>("last_flower_x", -1);
    bee.newVariable<int>("last_flower_y", -1);
    bee.newVariable<int>("is_at_flower", 0);
    bee.newVariable<int>("target_has_nectar", 0);
    bee.newVariable<int>("moved_this_step", 0); //for the exit function

    map<string, string> myBeeMap = {
         {"priority", "priority_main"},      // API wants 'priority', you have 'priority_main'
         {"moved_this_step", "did_i_move"}   // API wants 'moved_this_step', you have 'did_i_move'
     };
    
    map<string, string> myFlowerMap = {
         {"resource_value", "nectar"}        // API wants 'resource_value', you have 'nectar'
    };

    // Add movement submodel
    SubModelDescription sub_model_move = MovementAPI::define_submodel(model, "bee", "cell", ENV_DIM, ENV_DIM, myBeeMap, myFlowerMap);

    // Agent functions in parent model
    AgentFunctionDescription calc_priority = bee.newFunction("calculate_priority", calculate_priority);
    AgentFunctionDescription update_h_w = bee.newFunction("update_hunger_wait", update_hunger_wait);

    //all other are affairs of the main model which has to update priorirty by itself
    LayerDescription l1 = model.newLayer();
    l1.addAgentFunction(calc_priority);

    LayerDescription l2 = model.newLayer();
    l2.addSubModel(movement_sub); 

    LayerDescription l3 = model.newLayer();
    l3.addAgentFunction(update_h_w);

    // Initialisation functions
    model.addInitFunction(createAgent);
    
    // Step function
    model.addStepFunction(stepLogger);

    // Exit function
    model.addExitFunction(exitLog);
}

int main(int argc, const char ** argv) {
    ModelDescription model("submodelmodel");

    define_model(model);

    // Simulation configuration
    CUDASimulation simulation(model);
    simulation.SimulationConfig().random_seed = std::random_device{}();
    simulation.SimulationConfig().steps = SIMULATION_STEPS;
    
    simulation.simulate();

    return EXIT_SUCCESS;
}
