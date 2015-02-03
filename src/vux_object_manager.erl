-module(vux_object_manager).
-compile(export_all).

-include_lib("amqp_client/include/amqp_client.hrl").


init({Channel, WorldManagerExchange, WorldObjectExchange}, StateList, N) ->
    %% create world manager exchange
    vux_rmq_utils:exchange_declare(Channel, WorldManagerExchange, <<"fanout">>),

    vux_rmq_utils:exchange_declare(Channel, WorldObjectExchange, <<"fanout">>),
    WorldObjectQ = vux_rmq_utils:queue_declare(Channel),
    vux_rmq_utils:queue_bind(Channel, WorldObjectExchange, WorldObjectQ),
    %% broadcast the initial state of the universe\
    vux_rmq_utils:publish(Channel, WorldManagerExchange, StateList),

    %% subscribe to the state of the world
    vux_rmq_utils:subscribe(Channel, WorldObjectQ),

    %% initialize the main loop
    world_manager_loop(Channel, WorldManagerExchange, [], N, N).

world_manager_loop(Channel, WorldManagerExchange, WorldObjectStateList,  N, 0) ->
    %% TODO: SAVE STATE TO DB
    %% broadcast the current state of the universe
    vux_rmq_utils:publish(Channel, WorldManagerExchange, WorldObjectStateList),
    world_manager_loop(Channel, WorldManagerExchange, [], N, N);
world_manager_loop(Channel,  WorldManagerExchange, WorldObjectStateList, N, Count) ->
    receive
        %% A delivery
        {#'basic.deliver'{delivery_tag = Tag}, #amqp_msg{payload = WorldObjectState}} ->
	    %% {Pid , _, _, Cycle} = binary_to_term(WorldObjectState),
            %% io:format("pid : ~p , cycle : ~p ~n", [Pid, Cycle]),

            %% Ack the message
            vux_rmq_utils:ack(Channel, Tag),

            WorldObjectStateList2 = [WorldObjectState | WorldObjectStateList],

            %% Loop
            world_manager_loop(Channel, WorldManagerExchange, WorldObjectStateList2, N, Count-1);
        %% This is received when the subscription is cancelled
        #'basic.cancel_ok'{} ->
            cancel_ok;
        _ ->
            world_manager_loop(Channel, WorldManagerExchange, WorldObjectStateList, N, Count)
    end.
