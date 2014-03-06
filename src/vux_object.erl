-module(vux_object).
-compile(export_all).

-include_lib("amqp_client/include/amqp_client.hrl").

init({Channel, WorldManagerQ, WorldObjectExchange}, X, Y, Cycle, MaxX, MaxY) ->
    Sub = #'basic.consume'{queue = WorldManagerQ},
    #'basic.consume_ok'{consumer_tag = _Tag} = amqp_channel:subscribe(Channel, Sub, self()),
    receive
        #'basic.consume_ok'{} -> ok
    end,
    world_object_loop({Channel, WorldManagerQ, WorldObjectExchange}, X, Y, Cycle, MaxX, MaxY).

world_object_loop({Channel, WorldManagerQ, WorldObjectExchange}, X, Y, Cycle, MaxX, MaxY) ->
    receive
        %% A delivery
        {#'basic.deliver'{delivery_tag = Tag}, #amqp_msg{payload = WorldStateListP}} ->
            %% Ack the message
            amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),

            WorldStateList = binary_to_term(WorldStateListP),
            {X1, Y1} = calculate_state(WorldStateList, X, Y, MaxX, MaxY),
            Publish = #'basic.publish'{exchange = WorldObjectExchange,
                                       routing_key = <<"#">>},
            Payload = term_to_binary({self(), X1, Y1, Cycle+1}),
            amqp_channel:cast(Channel, Publish, #amqp_msg{payload = Payload}),

            %% Loop
            world_object_loop({Channel, WorldManagerQ, WorldObjectExchange}, X, Y, Cycle+1, MaxX, MaxY);
        %% This is received when the subscription is cancelled
        #'basic.cancel_ok'{} ->
            cancel_ok;
        _ ->
            world_object_loop({Channel, WorldManagerQ, WorldObjectExchange}, X, Y, Cycle, MaxX, MaxY)
    end.
    %% receive
    %%     {SubChannel, StateList} ->
    %%         {X1, Y1} = calculate_state(StateList, X, Y, MaxX, MaxY),
    %%         publish_state(PubChannel, {self(), X1, Y1, Cycle + 1}),
    %%         world_object_loop(SubChannel, PubChannel, X1, Y1, Cycle + 1, MaxX, MaxY);
    %%     _ ->
    %%         world_object_loop(SubChannel, PubChannel, X, Y, Cycle, MaxX, MaxY)
    %% end.

calculate_state(_, MaxX, MaxY, MaxX, MaxY) ->
    {MaxX, MaxY};
calculate_state(_StateList, X, Y, MaxX, MaxY) ->
    Xadd = crypto:rand_uniform(-1, 1),
    Yadd = crypto:rand_uniform(-1, 1),
    X1 = X + Xadd,
    Y1 = Y + Yadd,
    X2 = if X1 >= MaxX -> MaxX;
            X1 =< -MaxX -> -MaxX;
            true -> X1
         end,
    Y2 = if Y1 >= MaxY -> MaxY;
            Y1 =< -MaxY -> -MaxY;
            true -> Y1
         end,
    {X2, Y2}.
