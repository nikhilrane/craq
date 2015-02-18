%% @author D063582
%% @doc @todo Add description to code_lock.


-module(code_lock).
-behaviour(gen_fsm).

-export([start_link1/2, send_by_pid/2, send_by_name/2]).
-export([button/1, start_procs/0]).
-export([init/1, locked/2, open/2]).
%% ====================================================================
%% API functions
%% ====================================================================




%% ====================================================================
%% Internal functions
%% ====================================================================

start_procs() ->
	P1 = spawn(?MODULE, start_link1, [111, 1234]),
	P2 = spawn(?MODULE, start_link1, [222, 7890]),
	{ok, P1, P2}.


start_link1(Name, Code) ->
    gen_fsm:start_link(Name, code_lock, Code, []).

button(Digit) ->
	io:format("Sending Digit: ~w", [Digit]),
    gen_fsm:send_event(code_lock, {button, Digit}).

send_by_pid(Pid, Digit) ->
	io:format("Sending By Pid, Digit: ~w", [Digit]),
    gen_fsm:send_event(Pid, {button, Digit}).

send_by_name(Name, Digit) ->
	io:format("Sending By Pid, Digit: ~w", [Digit]),
    gen_fsm:send_event(Name, {button, Digit}).

init(Code) ->
    {ok, locked, {[], Code}}.

locked({button, Digit}, {SoFar, Code}) ->
	io:format("Called locked with: ~w, ~w, ~w", [Digit, SoFar, Code]),
    case [Digit|SoFar] of
        Code ->
            io:format("call do_unlock() here!"),
            {next_state, open, {[], Code}, 30000};
        Incomplete when length(Incomplete)<length(Code) ->
			io:format("Going through Incomplete with: ~w, ~w, ~w", [Digit, SoFar, Code]),
            {next_state, locked, {Incomplete, Code}};
        _Wrong ->
			io:format("Going wrong with: ~w, ~w, ~w", [Digit, SoFar, Code]),
            {next_state, locked, {[], Code}}
    end.

open(timeout, State) ->
    io:format("call do_lock() here!"),
    {next_state, locked, State}.