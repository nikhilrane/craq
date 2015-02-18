%% @author D063582
%% @doc @todo Add description to ring_node.


-module(ring_node).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start_node/1, listen_requests/3]).


start_node(Node_Name) ->
	spawn(ring_node, listen_requests, [Node_Name]),
	io:format("Listening on ~w", [Node_Name]),
end.

%% ====================================================================
%% Internal functions
%% ====================================================================

listen_requests(Node_Name, Prev_Node, Next_Node, Key_List) ->
	receive
		%% Register Previous and Next Nodes
		{From_Node, previous, Node_Pid} ->
			Prev_Node = Node_Pid;
		
		{From_Node, next, Node_Pid} ->
			Next_Node = Node_Pid;
		
		%% Handle replication requests
		{From_Node, record, sync_rep, Key, Value, Factor} when Factor > 0 ->
			io:format("Received: ~w~n", [Value]),
			%% write to local file also
			New_Key_List = [{Key, Value, 0} | Key_List],
			
			%% Factor is greater than 0, so send to next node
			Next_Node ! {self(), Node_Name, record, sync_rep, Key, Value, Factor-1},
			listen_requests(Node_Name, Prev_Node, Next_Node, New_Key_List);
		
		{From_Node, record, sync_rep, Key, Value, Factor} when Factor =:= 0 ->
			io:format("Received when 0: ~w~n", [Value]),
			%% write to local file also
			New_Key_List = [{Key, Value, 1} | Key_List],
			
			%% Factor is reached, so send ACK to previous node
			Prev_Node ! {self(), Node_Name, ack, Key},
			listen_requests(Node_Name, Prev_Node, Next_Node, New_Key_List);
			
		{From_Node, His_Name, ack, Key} ->
			case lists:keyfind(Key, 1, Key_List) of
				{Key, Value, 0} ->
					%% Update Ack bit and send Ack to Prev_Node
			
			New_Key_List = lists:keyreplace(Key, 1, Key_List, ),
			Prev_Node ! {self(), Node_Name, ack, Key},
			listen_requests(Node_Name, Prev_Node, Next_Node, New_Key_List)

		%% handle node failure/restart


	end,
	listen_requests(Node_Name, Prev_Node, Next_Node, Key_List).


%%=ERROR REPORT==== 9-Feb-2015::11:06:57 ===
%%Error in process <0.72.0> on node 'Node1@WDFN00299981A.emea.global.corp.sap' with exit value: 
%%{undef,[{ring_node,listen_requests,['Node1@WDFN00299981A.emea.global.corp.sap','Node3@WDFN00299981A.emea.global.corp.sap','Node2@WDFN00299981A.emea.global.corp.sap'],[]}]}
			

