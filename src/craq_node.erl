%% @author D063582
%% @doc @todo Add description to craq_node.


-module(craq_node).

-record(state, {own_name, prev, next, monitor, keys=[]}).		%% monitor is to keep a Ref to next process, so when it fails, we could fail the transaction
																%% current not used though

%% ====================================================================
%% API functions
%% ====================================================================
-export([start_node/1, init/1]).

start_node(Node_Name) ->
	{ok, spawn(?MODULE, init, [Node_Name])}.


%% ====================================================================
%% Internal functions
%% ====================================================================

init(Node_Name) ->
	S=#state{own_name=Node_Name},
	io:format("init success!~n"),
	loop(S).


loop(S) ->
	receive
		%% configure call to set PREV and NEXT nodes
		{config, Prev, Next} ->
			{ok, S_New} = configure({config, Prev, Next}, S);
		
		%% Initiating the replication algorithm
		{initiate, From, Key, Master, Value, Factor} ->
			{ok, S_New} = start_algo({initiate, From, Key, Master, Value, Factor}, S);
		
		%% Replicate call to copy, and forward based on Factor
		{replicate, From, Key, Value, Master, Factor} ->
			{ok, S_New} = forward({replicate, From, Key, Value, Master, Factor}, S);
		
		%% Handle ACK messages
		{ack, From, Key} ->
			{ok, S_New} = expect_ack({ack, From, Key}, S)
	end,
	loop(S_New).


%% configure state, set the prev and next node
configure({config, Prev, Next}, S) ->
	io:format("  ~w)  Got an event with Node: ~w, ~w~n", [S#state.own_name, Prev, Next]),
	S_New = S#state{prev = Prev, next = Next},
	io:format("Prev and Next set!"),
	{ok, S_New}.

	%% Need Error Handling here
	%% 	_ ->
	%% 		io:format("Error in configure method, received: ~w, ~w~n. Ignoring!!!", [Type, Some_Node]),
	%% 		{ok, S}.



%% initiate the <Key, Value> message to be passed to next nodes
start_algo({initiate, From, Key, Master, Value, Factor}, S) ->
	case lists:keyfind(Key, 1, S#state.keys) of
		false ->
			if
				is_pid(Master) ->
					%% S#state.keys=[ {Key, Value, Master, 0} | S#state.keys ];
					S_New = S#state{ keys=[ {Key, Value, Master, 0} | S#state.keys ]};
				true ->
					%% S#state.keys=[ {Key, Value, self(), 0} | S#state.keys ]
					S_New = S#state{ keys=[ {Key, Value, self(), 0} | S#state.keys ]}
			end,

			io:format("  ~w)  List: ~w~n", [S_New#state.own_name, S_New#state.keys]),
			
			%% trivial case, initiate a hello message
			S_New#state.next ! {replicate, self(), Key, Value, self(), Factor - 1},		%% forward for replication as: {request_type=replicate, my_pid, Key, Value, Master, Factor}
			{ok, S_New};
		
		{_} ->
			%% this should not happen, ideally throw an Exception
			Error_Code={error, already_initiated_with_this_key},
			exit(Error_Code)
	end.


%% when receive a forward for replication, replicate, check factor and either forward OR send back ack
forward({replicate, From, Key, Value, Master, Factor}, S) ->
	case lists:keyfind(Key, 1, S#state.keys) of
		false ->
			if
				Factor > 0 ->
					%% this means we still need to replicate this <Key, Value> ahead so forward it
					S_New = S#state{ keys=[ {Key, Value, Master, 0} | S#state.keys ]},
					io:format("  ~w)  Replicated Key: ~w~n", [S_New#state.own_name, Key]),
					S_New#state.next ! {replicate, self(), Key, Value, Master, Factor-1},
					io:format("  ~w)  Factor > 0, hence forwarding", [S_New#state.own_name]),
					{ok, S_New};
				true ->
					%% replication factor reached, just send back an ACK
					S_New = S#state{ keys=[ {Key, Value, Master, 1} | S#state.keys ]},
					S_New#state.prev ! {ack, self(), Key},
					io:format("  ~w)  Factor reached, hence sending back ACK.", [S_New#state.own_name]),
					{ok, S_New}
			end;

		{_} ->
			%% we already have the key, let's just ignore it
			io:format("  ~w)  Received Key: ~w twice. This time from: ~w~n ", [S#state.own_name, Key, From]),
			{ok, S}
	end.
				

%% When INITIATED/FORWARDED a <key, value> pair, enter this state until we receive an ACK
expect_ack({ack, From, Key}, S) ->
	
	case {Key, Value, Master, Ack}=lists:keyfind(Key, 1, S#state.keys) of
		{Key, _, _, 0} ->
			io:format("  ~w)  Replacing ack bit, here's prevTuple: ~w~n", [S#state.own_name, {Key, Value, Master, Ack}]),
			%% trivial case, update ack to 1
			S_New = S#state{ keys = lists:keyreplace(Key, 1, S#state.keys, {Key, Value, Master, 1}) },
			
			if
				Master /= self() ->
					%% We just got an ACK, need to route it back, so send to prev node.
					S_New#state.prev ! {ack, self(), Key},
					io:format("  ~w)  Got Ack for Key: ~w, From: ~w~n", [S_New#state.own_name, Key, From]);
				true ->
					io:format("  ~w)  Received final ACK at the Master.", [S_New#state.own_name])
					
			end,
			{ok, S_New};

		{Key, _, _, 1} ->
			%% should not be here, Key is already acknowledged, let's ignore
			io:format("  ~w)  Already ACKed Key: ~w. This time from: ~w~n", [S#state.own_name, Key, From]),
			{ok, S};
		
		{_, _, _, _} ->
			Error_Code={error, in_expect_ack, got_unexpected},
			exit(Error_Code)
	end.




