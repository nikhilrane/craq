%% @author D063582
%% @doc @todo Add description to fsm_try.


-module(fsm_try).
-behaviour(gen_fsm).

-record(state, {own_name, prev, next, monitor, keys=[]}).		%% monitor is to keep a Ref to next process, so when it fails, we could fail the transaction
																%% current not used though

%% ====================================================================
%% API functions
%% ====================================================================
-export([init_spawn/0, init/1, configure/2, idle/2, forward/2, expect_ack/2, router/2, start_fsm/1]).
-export([code_change/4, handle_event/3, handle_info/3, handle_sync_event/4, terminate/3]).

%% spawn prev & next processes
init_spawn() ->
	N1 = spawn(?MODULE, start_fsm, ["Node1"]),
	N2 = spawn(?MODULE, start_fsm, ["Node2"]),
	N3 = spawn(?MODULE, start_fsm, ["Node3"]),
	N4 = spawn(?MODULE, start_fsm, ["Node4"]),
	N5 = spawn(?MODULE, start_fsm, ["Node5"]),
	{ok, N1, N2, N3, N4, N5}.


start_fsm(Node_Name) ->
	%% gen_fsm:start_link({local, craq}, fsm_try, S, []).
	io:format("in start_fsm for: ~w~n", [Node_Name]),
	gen_fsm:start_link(?MODULE, Node_Name, []).


%% ====================================================================
%% Internal functions
%% ====================================================================

init(Node_Name) ->
	io:format("At least came here!"),
	S=#state{own_name=Node_Name},
	{ok, configure, S}.


%% Not sure if we need this router
router(Pid, Event) ->
	io:format("Got event with data: ~w, ~w~n", [Pid, Event]),
	gen_fsm:send_event(Pid, Event).


%% configure state, set the prev and next node
configure({config, Type, Some_Node}, S) ->
	io:format("Got an event with Node: ~w~n", [Some_Node]),
	case Type of
		prev ->
			S_New=S#state{prev=Some_Node},
			io:format("Prev set to ~w~n", [S_New#state.prev]),
			if
				is_pid(S#state.next) ->
					io:format("Config done, move to next state."),
					{next_state, idle, S_New};
				true ->
					io:format("Next not set, going back to configure state."),
					{next_state, configure, S_New}
			end;
		next ->
			S_New=S#state{next=Some_Node},
			io:format("Next set to ~w~n", [S_New#state.next]),
			if
				is_pid(S#state.prev) ->
					io:format("Config done, move to next state."),
					{next_state, idle, S_New};
				true ->
					io:format("Prev not set, going back to configure state."),
					{next_state, configure, S_New}
			end;
		
		_ ->
			io:format("Error in configure method, received: ~w, ~w~n", [Type, Some_Node])
	end.


%% initiate a message to be passed to next nodes
idle({initiate, From, Key, Master, Value}, S) ->
	case lists:keyfind(Key, 1, S#state.keys) of
		false ->
			if
				is_pid(Master) ->
					%% S#state.keys=[ {Key, Value, Master, 0} | S#state.keys ];
					_=S#state{ keys=[ {Key, Value, Master, 0} | keys ]};
				true ->
					%% S#state.keys=[ {Key, Value, self(), 0} | S#state.keys ]
					_=S#state{ keys=[ {Key, Value, self(), 0} | keys ]}
			end,

			io:format("List: ~w~n", [S#state.keys]),
			
			%% trivial case, initiate a hello message
			S#state.next ! {replicate, self(), Key, Value, self(), 3},		%% forward for replication as: {request_type=replicate, my_pid, Key, Value, Master, Factor}
			{next_state, expect_ack, S};
		
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
					_=S#state{ keys=[ {Key, Value, Master, 0} | keys ]},
					io:format("Replicated Key: ~w~n", [Key]),
					S#state.next ! {replicate, self(), Key, Value, Master, Factor-1},
					io:format("Factor > 0, hence forwarding"),
					{next_state, expect_ack, S};
				true ->
					%% replication factor reached, just send back an ACK
					_=S#state{ keys=[ {Key, Value, Master, 1} | keys ]},
					S#state.prev ! {ack, self(), Key},
					io:format("Factor reached, hence sending back ACK."),
					{next_state, idle, S}
			end;

		{_} ->
			%% we already have the key, let's just ignore it
			io:format("Received Key: ~w twice. This time from: ~w~n ", [Key, From]),
			{next_state, idle, S}
	end.
				

%% When INITIATED/FORWARDED a <key, value> pair, enter this state until we receive an ACK
expect_ack({ack, From, Key}, S) ->
	%% case Tuple=lists:keyfind(Key, 1, S#state.keys) of
	case {Key, Value, Master, Ack}=lists:keyfind(Key, 1, S#state.keys) of
		{Key, _, _, 0} ->
			io:format("Replacing ack bit, here's prevTuple: ~w~n", [{Key, Value, Master, Ack}]),
			%% trivial case, update ack to 1
			lists:keyreplace(Key, 1, S#state.keys, {Key, Value, Master, 1}),
			
			if
				Master /= self() ->
					%% We just got an ACK, need to route it back so send to prev node.
					S#state.prev ! {ack, self(), Key},
					io:format("Got Ack for ~w~n", [Key]);
				true ->
					io:format("Received final ACK at the Master.")
					
			end,
			{next_state, idle, S};

		{Key, _, _, 1} ->
			%% should not be here, Key is already acknowledged, let's ignore
			io:format("Already ACKed Key: ~w. This time from: ~w~n", [Key, From]),
			{next_state, idle};
		
		{_, _, _, _} ->
			Error_Code={error, in_expect_ack, got_unexpected},
			exit(Error_Code)
	end.


%% ====================================================================
%% Implementing callback functions
%% ====================================================================
code_change(A, B, C, S) ->
	io:format("code_change called with: {~w, ~w, ~w, ~w~n}", [A, B, C, S]),
	{ok, idle, S}.

handle_event(A, B, S) ->
	io:format("handle_event called with: {~w, ~w, ~w~n}", [A, B, S]),
	{stop, stopping_on_handle_event, S}.

handle_info({stats}, B, S) ->
	io:format("handle_info called with: {~w, ~w~n}", [ B, S]),
	{stop, stopping_on_handle_info, S}.

handle_sync_event(A, B, C, S) ->
	io:format("handle_sync_event called with: {~w, ~w, ~w, ~w~n}", [A, B, C, S]),
	{stop, stopping_on_handle_sync_event, S}.

terminate(A, B, S) ->
	{ok, terminating_from_terminate, A, B, S}.















