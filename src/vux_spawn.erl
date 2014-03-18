-module(vux_spawn).
-compile(export_all).

-include_lib("amqp_client/include/amqp_client.hrl").


start(MaxX, MaxY, N) ->
    %% initialize state of the universe
    StateList = generate_state_list(MaxX, MaxY, N),

    %% connecting to a broker
    % {ok, Connection} = amqp_connection:start(#amqp_params_network{}), 
    %% creating a channel
    % {ok, Channel} = amqp_connection:open_channel(Connection),
    Channel = get_channel("localhost"),

    %% create world manager exchange
    WorldManagerExchange = exchange_declare_fanout(Channel, <<"world_manager_exchange">>),
    % WorldManagerExchange =<<"world_manager_exchange">>,
    % amqp_channel:call(Channel, #'exchange.declare'{exchange = WorldManagerExchange,
    %                                                type = <<"fanout">>}),
    %% declare world manager queue
    #'queue.declare_ok'{queue = WorldManagerQ} =
        amqp_channel:call(Channel, #'queue.declare'{queue = <<"world_manager_queue">>}),

    %% create world object exchange
    WorldObjectExchange = <<"world_object_exchange">>,
    amqp_channel:call(Channel, #'exchange.declare'{exchange = WorldObjectExchange}),
    %% declare world object queue
    #'queue.declare_ok'{queue = WorldObjectQ} =
        amqp_channel:call(Channel, #'queue.declare'{queue = <<"world_object_queue">>}),

    amqp_channel:call(Channel, #'queue.bind'{exchange = WorldManagerExchange,
                                             queue = WorldManagerQ,
                                             routing_key = <<"#">>}),

    amqp_channel:call(Channel, #'queue.bind'{exchange = WorldObjectExchange,
                                             queue = WorldObjectQ,
                                             routing_key = <<"#">>}),

    WOPubSubInfo = {Channel, WorldManagerQ, WorldObjectExchange},
    WMPubSubInfo = {Channel, WorldObjectQ, WorldManagerExchange},

    InitialStateList = world_object_spawn(WOPubSubInfo, StateList, {MaxX, MaxY}),
    spawn(fun () -> world_manager(WMPubSubInfo, term_to_binary(InitialStateList), N) end).


world_object_spawn(PubSubInfo, StateList, {MaxX, MaxY}) ->
    [world_object_spawn(PubSubInfo, X, Y, {MaxX, MaxY}) || {X, Y} <- StateList].

world_object_spawn(PubSubInfo, X, Y, {MaxX, MaxY}) ->
    Pid = spawn(vux_object, init, [PubSubInfo, X, Y, 0, MaxX, MaxY]),
    {Pid, X, Y, 0}.


world_manager({Channel, WorldObjectQ, WorldManagerExchange}, StateList, N) ->
    %% send the initial state of the universe
    Publish = #'basic.publish'{exchange = WorldManagerExchange,
                               routing_key = <<"#">>},
    amqp_channel:cast(Channel, Publish, #amqp_msg{payload = StateList}),

    Sub = #'basic.consume'{queue = WorldObjectQ},
    #'basic.consume_ok'{consumer_tag = _Tag} = amqp_channel:subscribe(Channel, Sub, self()),
    receive
        #'basic.consume_ok'{} -> ok
    end,
    world_manager_loop(Channel, WorldManagerExchange, [], N, N).

world_manager_loop(Channel, WorldManagerExchange, WorldObjectStateList,  N, 0) ->
    %% SAVE STATE TO DB
    io:format("world state: ~p~n", [WorldObjectStateList]),
    Publish = #'basic.publish'{exchange = WorldManagerExchange,
                               routing_key = <<"#">>},
    amqp_channel:cast(Channel, Publish,
                      #amqp_msg{payload = term_to_binary(WorldObjectStateList)}),
    world_manager_loop(Channel, WorldManagerExchange, [], N, N);
world_manager_loop(Channel,  WorldManagerExchange, WorldObjectStateList, N, Count) ->
    receive
        %% A delivery
        {#'basic.deliver'{delivery_tag = Tag}, #amqp_msg{payload = WorldObjectState}} ->
            io:format("manager...~n"),

            %% Ack the message
            amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),

            WorldObjectStateList2 = [binary_to_term(WorldObjectState) | WorldObjectStateList],

            %% Loop
            world_manager_loop(Channel, WorldManagerExchange, WorldObjectStateList2, N, Count-1);
        %% This is received when the subscription is cancelled
        #'basic.cancel_ok'{} ->
            cancel_ok;
        _ ->
            world_manager_loop(Channel, WorldManagerExchange, WorldObjectStateList, N, Count)
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

get_channel(Host) ->
    case amqp_connection:start(#amqp_params_network{host = Host}) of
	{ok, Connection} ->
	    case amqp_connection:open_channel(Connection) of
		{ok, Channel} ->
		    Channel;
		_ ->
		    channel_error
	    end;
	_ ->
	    connection_error
    end.

exchange_declare_fanout(Channel, Exchange) ->
    amqp_channel:call(Channel, #'exchange.declare'{exchange = Exchange, type = <<"fanout">>}).

queue_declare(Channel, Queue, Exchange) ->
    #'queue.declare_ok'{queue = Queue} = amqp_channel:call(Channel, #'queue.declare'{exclusive = true}),
    amqp_channel:call(Channel, #'queue.bind'{exchange =  Exchange, queue = Queue}),
    Queue.
