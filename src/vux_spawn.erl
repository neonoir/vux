-module(vux_spawn).

-export([world_object_spawn/1]).
-export([world_object_spawn/2]).

start(MaxX, MaxY, N) ->
    StateList = generate_state_list(MaxX, MaxY, N),
    InitialStateList = world_object_spawn(StateList, {MaxX, MaxY}),
    publish_state_list(InitialStateList).

generate_state_list(MaxX, MaxY, N) ->
    %% [{X, Y}]
    generate_state_list(MaxX, MaxY, N, []).

generate_state_list(_, _, 0, Acc) ->
    Acc;
generate_state_list(MaxX, MaxY, N, Acc) ->
    X = crypto:rand_uniform(-MaxX, MaxX),
    Y = crypto:rand_uniform(-MaxY, MaxY),
    generate_state_list(MaxX, MaxY, N - 1, [{X, Y}|Acc]).

world_object_spawn(StateList, {MaxX, MaxY}) ->
    [world_object_spawn(X, Y, {MaxX, MaxY}) || {X, Y} <- StateList].

world_object_spawn(X, Y, {MaxX, MaxY}) ->
    Pid = spawn(vux_object, world_object_loop, [SubChannel, PubChannel, X, Y, 0, MaxX, MaxY]),
    {Pid, X, Y, 0}.
