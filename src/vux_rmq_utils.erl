-module(vux_rmq_utils).
-compile(export_all).

-include_lib("amqp_client/include/amqp_client.hrl").


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


exchange_declare(Channel, Exchange, Type) ->
    amqp_channel:call(Channel, #'exchange.declare'{exchange = Exchange, type = Type}).

queue_declare(Channel) ->
    #'queue.declare_ok'{queue = Queue} = amqp_channel:call(Channel, #'queue.declare'{exclusive = true}),
    Queue.

queue_bind(Channel, Exchange, Queue) ->
    amqp_channel:call(Channel, #'queue.bind'{exchange = Exchange, queue = Queue}).

publish(Channel, Exchange, Payload) ->
    amqp_channel:cast(Channel,
		      #'basic.publish'{exchange = Exchange},
		      #amqp_msg{payload = term_to_binary(Payload)}).

subscribe(Channel, Queue) ->
    #'basic.consume_ok'{consumer_tag = _Tag} = amqp_channel:subscribe(Channel,
                                                                      #'basic.consume'{queue = Queue},
                                                                      self()),
    receive
        #'basic.consume_ok'{} -> ok
    end.

ack(Channel, Tag) ->
    amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}).
