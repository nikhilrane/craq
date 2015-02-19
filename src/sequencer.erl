%% @author D063582
%% @doc @todo Add description to 'Sequencer'.


-module(sequencer).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/1, listen/1]).

start(LSN) ->
	{ok, spawn(?MODULE, listen, [LSN])}.


listen(LSN) ->
	receive
		{get, From, Amount} ->
%% 			io:format("Got req from: ~w", [From]),
			%% TODO perform house-keeping here
			LSN_New = LSN + Amount,
			From ! {lsn_value, self(), LSN};

		{stats, From} ->
			LSN_New = LSN,
			From ! {ok, LSN};
		{_} ->
			LSN_New = LSN,
			{error, "Not expecting to reach here!"}
	end,
	listen(LSN_New).



%% ====================================================================
%% Internal functions
%% ====================================================================


