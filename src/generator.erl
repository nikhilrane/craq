%% @author D063582
%% @doc @todo Add description to generator.


-module(generator).

%% ====================================================================
%% API functions
%% ====================================================================
-export([till/1]).


%% Given a 'Limit', returns a list: [1, 2, 3, ... , Limit] of byte_size = Limit
till(Limit) ->
	looper(Limit, []).


%% ====================================================================
%% Internal functions
%% ====================================================================

looper(0, L) ->
	io:format("Byte Size: ~w~n", [byte_size(list_to_binary(L))]),
	io:format("List: ~w~n", [[L]]),
	{ok, [L]};
looper(Limit, L) ->
	L_New = [Limit | L],
	looper(Limit - 1, L_New).

