
-module(replication_test).
-export([basic/1, write_one/3]).

basic(Factor) ->
	try
		%% Start the Sequencer
		{ok, Sequencer} = sequencer:start(1),
		
		%% Start the nodes in a Ring
		{ok, N1} = craq_node:start_node("Node1"),
		{ok, N2} = craq_node:start_node("Node2"),
		{ok, N3} = craq_node:start_node("Node3"),
		{ok, N4} = craq_node:start_node("Node4"),
		{ok, N5} = craq_node:start_node("Node5"),
		N1 ! {config, N5, N2},
		N2 ! {config, N1, N3},
		N3 ! {config, N2, N4},
		N4 ! {config, N3, N5},
		N5 ! {config, N4, N1},
		io:format("Initiating..."),
		
		%% initiate replication on N1
%% 		N1 ! {initiate, self(), 101, 'Val 101', Factor},
		
		%% initiate replication on N3
%% 		N3 ! {initiate, self(), 102, 'Val 102', Factor},

		spawn(?MODULE, write_one, [Sequencer, N1, Factor]),
		spawn(?MODULE, write_one, [Sequencer, N2, Factor]),
		spawn(?MODULE, write_one, [Sequencer, N3, Factor]),
		spawn(?MODULE, write_one, [Sequencer, N4, Factor]),
		spawn(?MODULE, write_one, [Sequencer, N5, Factor]),
		
		io:format("Done!")
	catch
		_:_ ->
			io:format("Some Exception...")
	end.


write_one(Sequencer, Proc, Factor) ->
%% 	io:format("Starting write req.~n"),
	Sequencer ! {get, self(), 1},
	receive
		{lsn_value, From, LSN} ->
			io:format("Got reply with LSN: ~w", [LSN]),
			Key = LSN,
			Val = float_to_binary(random:uniform() * 1000000),
			Proc ! {initiate, self(), Key, Val, Factor};
		_ ->
			exit("Not Expected in replication_test:write_one()")
	end,
%% 	io:format("Requesting LSN.~n"),
	
	write_one(Sequencer, Proc, Factor).


test_avg(M, F, A, N) when N > 0 ->
    L = test_loop(M, F, A, N, []),
    Length = length(L),
    Min = lists:min(L),
    Max = lists:max(L),
    Med = lists:nth(round((Length / 2)), lists:sort(L)),
    Avg = round(lists:foldl(fun(X, Sum) -> X + Sum end, 0, L) / Length),
    io:format("Range: ~b - ~b mics~n"
          "Median: ~b mics~n"
          "Average: ~b mics~n",
          [Min, Max, Med, Avg]),
    Med.
 
test_loop(_M, _F, _A, 0, List) ->
    List;
test_loop(M, F, A, N, List) ->
    {T, _Result} = timer:tc(M, F, A),
    test_loop(M, F, A, N - 1, [T|List]).



%% start_listening() ->
%% 	receive
%% 		{stats_info, S_New} ->
%% 			io:format("~w: master_for = ~w, replicated = ~w,~nkeys = ~w", [own_name, master_for, replicated, keys=[]])
%% 	
%% 	end,
%% 	start_listening().
		 