-module(vux_object).
-compile(export_all).

-include_lib("amqp_client/include/amqp_client.hrl").

init({Channel, WorldManagerExchange, WorldObjectExchange}, X, Y, Cycle, MaxX, MaxY) ->
    vux_rmq_utils:exchange_declare(Channel, WorldObjectExchange, <<"fanout">>),
    vux_rmq_utils:exchange_declare(Channel, WorldManagerExchange, <<"fanout">>),
    WorldManagerQ = vux_rmq_utils:queue_declare(Channel),
    vux_rmq_utils:queue_bind(Channel, WorldManagerExchange, WorldManagerQ),

    vux_rmq_utils:subscribe(Channel, WorldManagerQ),
    world_object_loop({Channel, WorldManagerQ, WorldObjectExchange}, X, Y, Cycle, MaxX, MaxY).

world_object_loop({Channel, WorldManagerQ, WorldObjectExchange}, X, Y, Cycle, MaxX, MaxY) ->
    receive
        %% A delivery
        {#'basic.deliver'{delivery_tag = Tag}, #amqp_msg{payload = WorldStateListP}} ->
            %% Ack the message
            vux_rmq_utils:ack(Channel, Tag),

            WorldStateList = binary_to_term(WorldStateListP),
            {X1, Y1} = calculate_state(WorldStateList, X, Y, MaxX, MaxY),
            Payload = {self(), X1, Y1, Cycle+1},
            io:format("payload: ~p~n", [Payload]),
            vux_rmq_utils:publish(Channel, WorldObjectExchange, Payload),

            %% Loop
            world_object_loop({Channel, WorldManagerQ, WorldObjectExchange}, X, Y, Cycle+1, MaxX, MaxY);
        %% This is received when the subscription is cancelled
        #'basic.cancel_ok'{} ->
            cancel_ok;
        _ ->
            world_object_loop({Channel, WorldManagerQ, WorldObjectExchange}, X, Y, Cycle, MaxX, MaxY)
    end.


calculate_state(_, MaxX, MaxY, MaxX, MaxY) ->
    {MaxX, MaxY};
calculate_state(_, MaxX, _, MaxX, MaxY) ->
    {MaxX, MaxY};
calculate_state(_, _, MaxY, MaxX, MaxY) ->
    {MaxY, MaxY};
calculate_state(_StateList, X, Y, MaxX, MaxY) ->
    Xadd = crypto:rand_uniform(-2, 2),
    Yadd = crypto:rand_uniform(-2, 2),
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
