-module(vertex).

%% add player
%% player log
%% vertex log
%% time machine: go back in log
%% should player see older self?
%% should universe be forked?
%% wormhole: a vertex with 0 distance between two vertices
%% higher dimension: a vertex with 0 distance to all vertices
%% quantum entaglement


add_vertex() ->
    spawn_link(fun() -> vertex_loop([]) end).

add_vertex(Vertex) ->
    NewVertex = add_vertex(),
    add_edge(Vertex, NewVertex).

add_vertex_two_way(Vertex) ->
    NewVertex = add_vertex(),
    two_way_edge(Vertex, NewVertex).    

add_edge(Vertex1, Vertex2) ->
    Vertex1 ! {add_edge, Vertex2}.

list_vertics(Vertex) ->
    Vertex ! {list_vertics, self()},
    receive
	VertexList ->
	    VertexList
    end.

two_way_edge(Vertex1, Vertex2) ->
    add_edge(Vertex1, Vertex2),
    add_edge(Vertex2, Vertex1).

vertex_loop(VertexList) ->
    receive
	{add_edge, Vertex} ->
	    VertexList2 = [Vertex | VertexList],
	    vertex_loop(VertexList2);
	{list_vertics, From} ->
	    From ! VertexList
    end.
