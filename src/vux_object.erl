-module(vux_object).

-export([new/1]).

new({X, Y}) ->
    {crypto:rand_uniform(-X, X), crypto:rand_uniform(-Y, Y)}.
