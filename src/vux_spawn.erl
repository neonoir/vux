-module(vux_spawn).
-compile(export_all).

-include_lib("amqp_client/include/amqp_client.hrl").


start(MaxX, MaxY, N) ->
    StateList = generate_state_list(MaxX, MaxY, N),

    %% connecting to a broker
    {ok, Connection} = amqp_connection:start(#amqp_params_network{}),
    %% creating a channel
    {ok, Channel} = amqp_connection:open_channel(Connection),

    %% create world manager exchange
    WorldManagerExchange = #'exchange.declare'{exchange = <<"world_manager_exchange">>,
                                               type = <<"fanout">>},
    amqp_channel:call(Channel, WorldManagerExchange),
    %% declare world manager queue
    #'queue.declare_ok'{queue = WorldManagerQ} =
        amqp_channel:call(Channel, #'queue.declare'{queue = <<"world_manager_queue">>}),

    %% create world object exchange
    WorldObjectExchange = #'exchange.declare'{exchange = <<"world_object_exchange">>,
                                              type = <<"fanout">>},
    amqp_channel:call(Channel, WorldObjectExchange),
    %% declare world object queue
    #'queue.declare_ok'{queue = WorldObjectQ} =
        amqp_channel:call(Channel, #'queue.declare'{queue = <<"world_object_queue">>}),
    %% amqp_channel:cast(Channel, Publish, #amqp_msg{payload = StateList}),

    WOPubSubInfo = {Channel, WorldManagerQ, WorldObjectExchange},
    WMPubSubInfo = {Channel, WorldObjectQ, WorldManagerExchange},

    InitialStateList = world_object_spawn(WOPubSubInfo, StateList, {MaxX, MaxY}),
    world_manager(WMPubSubInfo, InitialStateList, N).


world_object_spawn(PubSubInfo, StateList, {MaxX, MaxY}) ->
    [world_object_spawn(PubSubInfo, X, Y, {MaxX, MaxY}) || {X, Y} <- StateList].

world_object_spawn(PubSubInfo, X, Y, {MaxX, MaxY}) ->
    Pid = spawn(vux_object, init, [PubSubInfo, X, Y, 0, MaxX, MaxY]),
    {Pid, X, Y, 0}.


world_manager({Channel, WorldObjectQ, WorldManagerExchange}, StateList, N) ->
    amqp_channel:cast(Channel, #'basic.publish'{exchange = WorldManagerExchange},
                      #amqp_msg{payload = StateList}),
    Sub = #'basic.consume'{queue = WorldObjectQ},
    #'basic.consume_ok'{consumer_tag = _Tag} = amqp_channel:subscribe(Channel, Sub, self()),
    world_manager_loop(Channel, WorldManagerExchange, [], N, N).

world_manager_loop(Channel,  WorldManagerExchange, WorldObjectStateList,  N, 0) ->
    %% SAVE STATE TO DB
    io:format("~p~n", [WorldObjectStateList]),
    amqp_channel:cast(Channel, WorldManagerExchange, #amqp_msg{payload = WorldObjectStateList}),
    world_manager_loop(Channel, WorldManagerExchange, [], N, N);
world_manager_loop(Channel,  WorldManagerExchange, WorldObjectStateList, N, Count) ->
    receive
        %% This is the first message received
        #'basic.consume_ok'{} ->
            world_manager_loop(Channel, WorldManagerExchange, WorldObjectStateList, N, Count);
        %% This is received when the subscription is cancelled
        #'basic.cancel_ok'{} ->
            cancel_ok;
        %% A delivery
        {#'basic.deliver'{delivery_tag = Tag}, WorldObjectState } ->
            WorldObjectStateList2 = [WorldObjectState | WorldObjectStateList],

            %% Ack the message
            amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),

            %% Loop
            world_manager_loop(Channel, WorldManagerExchange, WorldObjectStateList2, N, Count-1)
    end.



generate_state_list(MaxX, MaxY, N) ->
    %% [{X, Y}]
    generate_state_list(MaxX, MaxY, N, []).

generate_state_list(_, _, 0, Acc) ->
    Acc;
generate_state_list(MaxX, MaxY, N, Acc) ->
    X = crypto:rand_uniform(-MaxX, MaxX),
    Y = crypto:rand_uniform(-MaxY, MaxY),
    generate_state_list(MaxX, MaxY, N - 1, [{X, Y}|Acc]).
