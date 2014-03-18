-module(vux_object_manager).
-compile(export_all).

-include_lib("amqp_client/include/amqp_client.hrl").


world_manager({Channel, WorldObjectQ, WorldManagerExchange}, StateList, N) ->

    %% broadcast the initial state of the universe
    amqp_channel:cast(Channel, 
		      #'basic.publish'{exchange = WorldManagerExchange}, 
		      #amqp_msg{payload = term_to_binary(StateList)}),

    %% subscribe to the state of the world
    Sub = #'basic.consume'{queue = WorldObjectQ},
    #'basic.consume_ok'{consumer_tag = _Tag} = amqp_channel:subscribe(Channel, Sub, self()),
    receive
        #'basic.consume_ok'{} -> ok
    end,
    world_manager_loop(Channel, WorldManagerExchange, [], N, N).

world_manager_loop(Channel, WorldManagerExchange, WorldObjectStateList,  N, 0) ->
    %% TODO: SAVE STATE TO DB
    io:format("world state: ~p~n", [WorldObjectStateList]),

    %% broadcast the current state of the universe
    amqp_channel:cast(Channel, 
		      #'basic.publish'{exchange = WorldManagerExchange},
                      #amqp_msg{payload = term_to_binary(WorldObjectStateList)}),
    world_manager_loop(Channel, WorldManagerExchange, [], N, N);
world_manager_loop(Channel,  WorldManagerExchange, WorldObjectStateList, N, Count) ->
    receive
        %% A delivery
        {#'basic.deliver'{delivery_tag = Tag}, #amqp_msg{payload = WorldObjectState}} ->
	    {Pid , _, _, Cycle} = binary_to_term(WorldObjectState),
            io:format("pid : ~p , cycle : ~p ~n", [Pid, Cycle]),

            %% Ack the message
            amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),

            WorldObjectStateList2 = [WorldObjectState | WorldObjectStateList],

            %% Loop
            world_manager_loop(Channel, WorldManagerExchange, WorldObjectStateList2, N, Count-1);
        %% This is received when the subscription is cancelled
        #'basic.cancel_ok'{} ->
            cancel_ok;
        _ ->
            world_manager_loop(Channel, WorldManagerExchange, WorldObjectStateList, N, Count)
    end.

