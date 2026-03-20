#ifndef MOVEMENT_SUBMODEL_H_
#define MOVEMENT_SUBMODEL_H_

#include "flamegpu/flamegpu.h"

using namespace flamegpu;

FLAMEGPU_AGENT_FUNCTION(flower_output_nectar, MessageNone, MessageSpatial2D) {
    FLAMEGPU->message_out.setLocation(
        FLAMEGPU->getVariable<float>("x"), 
        FLAMEGPU->getVariable<float>("y")
    );
    FLAMEGPU->message_out.setVariable<float>("nectar", FLAMEGPU->getVariable<float>("nectar"));
    FLAMEGPU->message_out.setVariable<id_t>("flower_id", FLAMEGPU->getID());

    return ALIVE;
}

FLAMEGPU_AGENT_FUNCTION(bee_requesting_and_moving, MessageSpatial2D, MessageSpatial2D) {
    float best_nectar = -1.0f;
    id_t best_flower_id = ID_NOT_SET;
    id_t last_flower_id = FLAMEGPU->getVariable<id_t>("last_flower_id");
    int status = FLAMEGPU->getVariable<int>("is_moving");
    float priority = FLAMEGPU->getVariable<float>("priority");
    float x_flower = 0.0f;
    float y_flower = 0.0f;

    if(status == 1) {
        // Continue moving towards current target
        float current_target_x = FLAMEGPU->getVariable<float>("target_x");
        float current_target_y = FLAMEGPU->getVariable<float>("target_y");
        float x = FLAMEGPU->getVariable<float>("x");
        float y = FLAMEGPU->getVariable<float>("y");
        float dx = current_target_x - x;
        float dy = current_target_y - y;

        if (abs(dx) > 1.0f || abs(dy) > 1.0f) {
            if (dx != 0.0f) x += (dx > 0.0f) ? 1.0f : -1.0f;
            if (dy != 0.0f) y += (dy > 0.0f) ? 1.0f : -1.0f;
            FLAMEGPU->setVariable<float>("x", x);
            FLAMEGPU->setVariable<float>("y", y);
            return ALIVE; // Keep moving
        } else {
            // Arrived at target (close enough)
            FLAMEGPU->setVariable<int>("at_flower", 1);
            FLAMEGPU->setVariable<int>("is_moving", 0);
            return ALIVE;
        }
    }

    // Search for best flower
    for (const auto& message : FLAMEGPU->message_in(FLAMEGPU->getVariable<float>("x"), FLAMEGPU->getVariable<float>("y"))) {
        float nectar = message.getVariable<float>("nectar");
        id_t flower_id = message.getVariable<id_t>("flower_id");

        if (nectar > best_nectar && flower_id != last_flower_id) {
            best_nectar = nectar;
            best_flower_id = flower_id;
            x_flower = message.getVariable<float>("x");
            y_flower = message.getVariable<float>("y");
        }
    }

    // Send the message to the flower to request movement towards it
    if(best_flower_id != ID_NOT_SET) {
        FLAMEGPU->setVariable<float>("target_x", x_flower);
        FLAMEGPU->setVariable<float>("target_y", y_flower);
        FLAMEGPU->setVariable<id_t>("target_flower_id", best_flower_id);
        
        // Output at the flower's location
        FLAMEGPU->message_out.setLocation(x_flower, y_flower);
        FLAMEGPU->message_out.setVariable<id_t>("bee_id", FLAMEGPU->getID());
        FLAMEGPU->message_out.setVariable<float>("priority", priority);
        // We need bee_x/y so the flower knows where to send the response
        FLAMEGPU->message_out.setVariable<float>("bee_x", FLAMEGPU->getVariable<float>("x"));
        FLAMEGPU->message_out.setVariable<float>("bee_y", FLAMEGPU->getVariable<float>("y"));
    }

    return ALIVE;
}

FLAMEGPU_AGENT_FUNCTION(movement_response, MessageSpatial2D, MessageSpatial2D) {
    id_t best_request_bee_id = ID_NOT_SET;
    float highest_priority = -1.0f;
    float best_bee_x = 0.0f;
    float best_bee_y = 0.0f;

    for (const auto& msg : FLAMEGPU->message_in(FLAMEGPU->getVariable<float>("x"), FLAMEGPU->getVariable<float>("y"))) {
        id_t bee_id = msg.getVariable<id_t>("bee_id");
        float priority = msg.getVariable<float>("priority");

        if (priority > highest_priority) {
            highest_priority = priority;
            best_request_bee_id = bee_id;
            best_bee_x = msg.getVariable<float>("bee_x");
            best_bee_y = msg.getVariable<float>("bee_y");
        }
    }

    if(best_request_bee_id != ID_NOT_SET) {
        // Send response back to the bee location
        FLAMEGPU->message_out.setLocation(best_bee_x, best_bee_y);
        FLAMEGPU->message_out.setVariable<id_t>("bee_id", best_request_bee_id);
        FLAMEGPU->message_out.setVariable<id_t>("flower_id", FLAMEGPU->getID());
        // We need flower_x/y for the bee to confirm target
        FLAMEGPU->message_out.setVariable<float>("flower_x", FLAMEGPU->getVariable<float>("x"));
        FLAMEGPU->message_out.setVariable<float>("flower_y", FLAMEGPU->getVariable<float>("y"));
    }

    return ALIVE;
}

FLAMEGPU_AGENT_FUNCTION(bee_receive_movement_response, MessageSpatial2D, MessageNone) {
    id_t my_id = FLAMEGPU->getID();
    id_t target_flower_id = FLAMEGPU->getVariable<id_t>("target_flower_id");
    
    if (target_flower_id != ID_NOT_SET) {
        // Read response from our own location
        for (const auto& msg : FLAMEGPU->message_in(FLAMEGPU->getVariable<float>("x"), FLAMEGPU->getVariable<float>("y"))) {
            if (msg.getVariable<id_t>("bee_id") == my_id && msg.getVariable<id_t>("flower_id") == target_flower_id) {
                FLAMEGPU->setVariable<int>("is_moving", 1);
                break;
            }
        }
    }

    return ALIVE;
}

void define_message_submodule(ModelDescription &smm) {
    MessageSpatial2D::Description nectar_message = smm.newMessage<MessageSpatial2D>("nectar_message");
    nectar_message.newVariable<id_t>("flower_id");
    nectar_message.newVariable<float>("nectar");
    nectar_message.setRadius(20.0f);
    nectar_message.setMin(0, 0);
    nectar_message.setMax(100, 100);

    MessageSpatial2D::Description bee_request_message = smm.newMessage<MessageSpatial2D>("bee_request_message");
    bee_request_message.newVariable<id_t>("bee_id");
    bee_request_message.newVariable<float>("priority");
    bee_request_message.newVariable<float>("bee_x");
    bee_request_message.newVariable<float>("bee_y");
    bee_request_message.setRadius(1.0f);
    bee_request_message.setMin(0, 0);
    bee_request_message.setMax(100, 100);

    MessageSpatial2D::Description flower_response_message = smm.newMessage<MessageSpatial2D>("flower_response_message");
    flower_response_message.newVariable<id_t>("bee_id");
    flower_response_message.newVariable<id_t>("flower_id");
    flower_response_message.newVariable<float>("flower_x");
    flower_response_message.newVariable<float>("flower_y");
    flower_response_message.setRadius(1.0f);
    flower_response_message.setMin(0, 0);
    flower_response_message.setMax(100, 100);
}

void define_agent_submodule(ModelDescription &smm) {
    AgentDescription flower_sm = smm.newAgent("flower_submodule");
    flower_sm.newVariable<id_t>("id", ID_NOT_SET);
    flower_sm.newVariable<float>("x");
    flower_sm.newVariable<float>("y");
    flower_sm.newVariable<float>("nectar");

    AgentDescription bee_sm = smm.newAgent("bee_submodule");
    bee_sm.newVariable<id_t>("id", ID_NOT_SET);
    bee_sm.newVariable<float>("x");
    bee_sm.newVariable<float>("y");
    bee_sm.newVariable<float>("priority", 0.0f);
    bee_sm.newVariable<float>("target_x");
    bee_sm.newVariable<float>("target_y");
    bee_sm.newVariable<id_t>("target_flower_id", ID_NOT_SET);
    bee_sm.newVariable<int>("at_flower", 0);
    bee_sm.newVariable<id_t>("last_flower_id", ID_NOT_SET);
    bee_sm.newVariable<int>("is_moving", 0);

    smm.Agent("flower_submodule").newFunction("flower_output_nectar", flower_output_nectar).setMessageOutput("nectar_message");

    AgentFunctionDescription b_req = smm.Agent("bee_submodule").newFunction("bee_requesting_and_moving", bee_requesting_and_moving);
    b_req.setMessageInput("nectar_message");
    b_req.setMessageOutput("bee_request_message");
    b_req.setMessageOutputOptional(true);

    AgentFunctionDescription m_res = smm.Agent("flower_submodule").newFunction("movement_response", movement_response);
    m_res.setMessageInput("bee_request_message");
    m_res.setMessageOutput("flower_response_message");
    m_res.setMessageOutputOptional(true);

    AgentFunctionDescription b_rec = smm.Agent("bee_submodule").newFunction("bee_receive_movement_response", bee_receive_movement_response);
    b_rec.setMessageInput("flower_response_message");
}

void define_layer_submodule(ModelDescription &smm) {
    smm.newLayer().addAgentFunction(flower_output_nectar);
    smm.newLayer().addAgentFunction(bee_requesting_and_moving);
    smm.newLayer().addAgentFunction(movement_response);
    smm.newLayer().addAgentFunction(bee_receive_movement_response);
}

SubModelDescription add_movement_submodel(ModelDescription &model) {
    ModelDescription sub_model_move("movement_submodel");
    define_message_submodule(sub_model_move);
    define_agent_submodule(sub_model_move);
    define_layer_submodule(sub_model_move);

    SubModelDescription smm = model.newSubModel("move", sub_model_move);
    smm.setMaxSteps(1);
    smm.bindAgent("bee_submodule", "bee", true, true);
    smm.bindAgent("flower_submodule", "flower", true, true);

    return smm;
}

#endif

