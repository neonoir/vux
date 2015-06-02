-module(vux_spawn).
-compile(export_all).

-include_lib("amqp_client/include/amqp_client.hrl").


start(MaxX, MaxY, N) ->
    %% initialize state of the universe
    StateList = generate_state_list(MaxX, MaxY, N),
    Channel = vux_rmq_utils:get_channel("localhost"),

    WorldManagerExchange = <<"world_manager_exchange">>,
    WorldObjectExchange = <<"world_object_exchange">>,

    PubSubInfo = {Channel, WorldManagerExchange, WorldObjectExchange},

    InitialStateList = world_object_spawn(PubSubInfo, StateList, {MaxX, MaxY}),
    spawn(fun () -> vux_object_manager:init(PubSubInfo, InitialStateList, N) end).


world_object_spawn(PubSubInfo, StateList, {MaxX, MaxY}) ->
    [world_object_spawn(PubSubInfo, X, Y, {MaxX, MaxY}) || {X, Y} <- StateList].

world_object_spawn(PubSubInfo, X, Y, {MaxX, MaxY}) ->
    Pid = spawn(vux_object, init, [PubSubInfo, X, Y, 0, MaxX, MaxY]),
    {Pid, X, Y, 0}.


generate_state_list(MaxX, MaxY, N) ->
    %% [{X, Y}]
    generate_state_list(MaxX, MaxY, N, []).

generate_state_list(_, _, 0, Acc) ->
    Acc;
generate_state_list(MaxX, MaxY, N, Acc) ->
    X = crypto:rand_uniform(-MaxX, MaxX),
    Y = crypto:rand_uniform(-MaxY, MaxY),
    generate_state_list(MaxX, MaxY, N - 1, [{X, Y}|Acc]).
