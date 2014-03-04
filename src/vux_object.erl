-module(vux_object).

-export([world_object_loop/7]).

world_object_loop(SubChannel, PubChannel, X, Y, Cycle, MaxX, MaxY) ->
    receive
        {SubChannel, StateList} ->
            {X1, Y1} = calculate_state(StateList, X, Y, MaxX, MaxY),
            publish_state(PubChannel, {self(), X1, Y1, Cycle + 1}),
            world_object_loop(SubChannel, PubChannel, X1, Y1, Cycle + 1, MaxX, MaxY);
        _ ->
            world_object_loop(SubChannel, PubChannel, X, Y, Cycle, MaxX, MaxY)
    end.

calculate_state(_, MaxX, MaxY, MaxX, MaxY) ->
    {MaxX, MaxY};
calculate_state(StateList, X, Y, MaxX, MaxY) ->
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
    {X2, Y2a}.
