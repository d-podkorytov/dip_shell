-module(user_default).
-compile(export_all).

-define(EDITOR,"ed").
-define(HELP(Cmd,Desc),io:format("~s:\t~s~n",[Cmd,Desc])).

% add your own commands to Erlang VM shell
%deinstall()->
% io:format("~s~n~n",["Remove the following line as the first line in your .erlang file in your home directory."]),
% io:format("~s~n",["code:load_abs(\"PATH/user_default\"),user_default:init_prompt()."]).
%
%install()->
%% io:format("~s~n~n",["Add the following line as the first line in your .erlang file in your home directory."]),
% HOME=case os:getenv("HOME") of
%   false -> os:getenv("USERPROFILE");% user's root for Windows
%   R0->R0
% end,
% io:format("HOME=~p~n",[HOME]),
% try file:rename(HOME++"/.erlang ",HOME++"/.erlang.old") of
%  {error,enoent} -> io:format("file ~s/.erlang was created at ~n",[HOME]);
%
%  R-> io:format("R=~p",[R]),
%      io:format("new file "++HOME++"/.erlang was created ~n",["~"]),
%      io:format("old file ~s/.erlang will be moved to ~s/.erlang.old ~n",[HOME,HOME])
%  catch
%  _:_ -> ""
% end,
%  
% {ok,F} = file:open(HOME++"/.erlang",[write]),
% {ok,CWD} = file:get_cwd(),
% io:format(F,"~s~n",["code:load_abs(\""++CWD++"/user_default\"),user_default:init_prompt()."]),
% file:close(F).

log_level(N)    -> logger:set_module_level(all,N).
log_level(Mod,N)-> logger:set_module_level(Mod,N).

local_time()-> calendar:local_time().
         %calendar:system_time_to_rfc3339(1).
home()-> 
  case os:getenv("HOME") of
   false -> os:getenv("USERPROFILE");% user's root for Windows
   R0->R0
 end.

get_env()-> 
  case os:getenv() of
   L->lists:map(fun(A)->list_to_tuple(string:tokens(A,"=")) end, L)
 end.

os_env()-> lists:map(fun(A)-> list_to_tuple(string:tokens(A,"=")) end,string:tokens(os:cmd("set"),"\n")).

os_env(Key) -> proplists:get_value(Key,os_env()).

get_env(Key)-> os:getenv(Key).
  
% show aliases
aliases()-> 
  {ok,PL} = file:consult(home()++"/.dip_aliases"),
            %io:format("Aliases: ~p~n",[PL]),
            PL.

% run alias from file "$HOME/.dip_aliases"
% it can run {Mod,Func,Arg} as Mod:Func(Arg)
%         or do RPC call for {Node,Mod,Func,Arg}
%         or {Nodes,Mod,Func,Arg}
%         or {cluster,Mod,Func,Arg}
a(Key) ->    a(Key,[],fun(_,A)->A end).
%a(Key,Args) -> a(Key,Args,fun(Args,A)->A end).       
a(Key,Args,F2) -> 
          case proplists:get_value(Key,aliases()) of
          L when is_list(L)   -> lists:map(fun({Mod,Fun})         -> nice_view(apply(Mod,Fun,Args));
                                              ({cluster,Mod,Fun})   -> lists:zip([node()|nodes()],nice_view(mcall(Mod,Fun,Args)));

                                              ({Mod,Fun,Arg})         -> nice_view(apply(Mod,Fun,Arg));
                                              ({cluster,Mod,Fun,Arg}) -> lists:zip([node()|nodes()],nice_view(mcall(Mod,Fun,Arg)));
                                              ({Nodes,Mod,Fun,Arg}) when is_list(Nodes) -> 
                                                                         lists:zip([node()|nodes()],nice_view(mcall(Nodes,Mod,Fun,Arg)));  
                                              ({Node,Mod,Fun,Arg})    -> {Node,nice_view(rpc:call(Node,Mod,Fun,Arg))};
                                              (A) -> {"can not evaluate",A}
                                           end         
                                           ,L);

           ({Mod,Fun})           -> nice_view(apply(Mod,Fun,Args));  
           ({cluster,Mod,Fun})   -> lists:zip([node()|nodes()],nice_view(mcall(Mod,Fun,Args)));

           {Mod,Fun,Arg}           -> nice_view(apply(Mod,Fun,Arg));
           {cluster,Mod,Fun,Arg}   -> lists:zip([node()|nodes()],nice_view(mcall(Mod,Fun,Arg)));
           {Nodes,Mod,Fun,Arg} when is_list(Nodes) -> 
                                      nice_view(mcall(Nodes,Mod,Fun,Arg));
           {Node,Mod,Fun,Arg}      -> {Node,nice_view(rpc:call(Node,Mod,Fun,Arg))}
          end.  

welcome()-> io:format("~p~n",[a(welcome)]).

nice_view(L)      when is_list(L)-> string:tokens(L,"\n");
nice_view({ok,L}) when is_list(L)-> {ok,string:tokens(L,"\n")};
nice_view({L,[]}) when is_list(L)-> string:tokens(L,"\n");
nice_view({L})    when is_list(L)->    string:tokens(L,"\n");
nice_view(A) ->   %io:format("niceview(A) A=~p ~n",[A]),
                  A. 
                       
ssh(Addr,Port,User)->
 ssh:start(),
 %{ok, ConRef} = 
 ssh:shell(Addr,Port,[{user,User}]).

scp(From,To,Port)  -> nice_view(os:cmd("scp -P "++integer_to_list(Port)++" "++From++" "++To)).

rec_loop(Acc)->
     receive
     {_,_,{data,_,_, Msg}} -> io:format("~p:~p ~p~n",[?MODULE,?LINE,Msg]),
                              rec_loop([Msg|Acc]);
                              
     {_,_,{eof,_}} -> 
                  lists:merge(lists:map(fun(Bin) when is_binary(Bin) -> string:tokens(binary_to_list(Bin),"\n");
                               (Term) -> Term  
                            end,Acc));
                              
     {_,_,Un} -> %io:format("~p:~p ~p~n",[?MODULE,?LINE,Un]),
                 %lists:map(fun(Bin) when is_binary(Bin) -> string:tokens(binary_to_list(Bin),"\n");
                 %             (Term) -> Term  
                 %          end,Acc)
                 [Un|Acc]                      

     after 3000 ->%io:format("~p:~p ~p~n",[?MODULE,?LINE,Acc]), 
                  lists:merge(lists:map(fun(Bin) when is_binary(Bin) -> string:tokens(binary_to_list(Bin),"\n");
                                           (Term) -> Term  
                                        end,
                                        Acc)
                             )                      

     end. 

ssh_exec()-> {addr,port,user,cmd}.

ssh_exec(Addr,Port,User,Pass,Cmd)->
% flush() or listen messages
 %spawn(fun()->  
 ssh:start(),
 {ok,ConRef}=ssh:connect(Addr,Port,[{user,User},{password,Pass}
                                   ]),
 {ok, SshConnectionChannelRef} = ssh_connection:session_channel(ConRef, 60000),
 Status=ssh_connection:exec(ConRef, SshConnectionChannelRef,Cmd, 60000),
% ssh_connection:reply_request(ConRef, true, Status,SshConnectionChannelRef),
 rec_loop([]).
 %end). 

% open pipes

%pipe_from({file,Name})->{ok,F}=file:open(Name,[read]),F;
%pipe_from(pid)->receive Msg->Msg after 2000-> timeout end.

%pipe_to({file,Name})  ->{ok,F}=file:open(Name,[write]),F.

% write to file session or tree of calls
write_do_file_session(File,F1) when is_function(F1,1) -> file:write(File,F1(File));
%write_do_file_session(File,F0) when is_function(F0,0) -> F0();
  
write_do_file_session(File,{Mod,F1,Arg})             -> file:write(File,apply(Mod,F1,Arg));    % debug or refactor it
write_do_file_session(File,{Node,Mod,F1,Arg})        -> file:write(File,rpc:call(Node,Mod,F1,Arg)); % debug or refactor it
  
write_do_file_session(File,[])            -> [];
write_do_file_session(File,L) when is_list(L)  -> lists:map(fun(A) -> write_do_file_session(File,A) end, L).  

% refactor it in the future

write_file_session(Name,F,Args) when is_atom(F) ->
                                    {ok,F}=file:open(Name,[write]),
                                    case apply(?MODULE,F,Args) of
                                     Bin when is_binary(Bin) -> file:write(F,Bin);
                                     Term -> io:format(F,"~p.~n",[Term])
                                    end,  
                                file:close(F).

write_file_session(Name,Mod,F,Args) when is_atom(F) ->
                                    {ok,F}=file:open(Name,[write]),
                                    case apply(Mod,F,Args) of
                                     Bin when is_binary(Bin) -> file:write(F,Bin);
                                     Term -> io:format(F,"~p.~n",[Term])
                                    end,  
                                file:close(F).

write_file_session(Name,Node,Mod,F,Args) when is_atom(F) ->
                                    {ok,F}=file:open(Name,[write]),
                                    case rpc:call(Node,Mod,F,Args) of
                                     Bin when is_binary(Bin) -> file:write(F,Bin);
                                     Term -> io:format(F,"~p.~n",[Term])
                                    end,  
                                file:close(F).

write_file_session(Name,F0) when is_atom(F0) ->
                                    {ok,F}=file:open(Name,[write]),
                                    case apply(?MODULE,F0,[]) of
                                     Bin when is_binary(Bin) -> file:write(F,Bin);
                                     Term -> io:format(F,"~p.~n",[Term])
                                    end,  
                                    file:close(F);

write_file_session(Name,F0) when is_function(F0,0) ->
                                    {ok,F}=file:open(Name,[write]),
                                    case F0() of
                                     Bin when is_binary(Bin) -> file:write(F,Bin);
                                     Term -> io:format(F,"~p.~n",[Term])
                                    end,  
                                    file:close(F);

write_file_session(Name,Functor)  ->{ok,F}=file:open(Name,[write]),
                                    write_do_file_session(F,Functor),  
                                    file:close(F).

file_info(DirOrFile)-> file:read_file_info(DirOrFile).

is_dir(Dir)-> try file_info(Dir) of
  {ok,{file_info,_,directory,_,
               _,
               _,
               _,
               _,_,_,_,_,_,_}} -> true;

  {ok,{file_info,_,_,_,
               _,
               _,
               _,
               _,_,_,_,_,_,_}} -> false;

   R -> {R,Dir}
   catch
    Err:Reason -> #{error => Err, reason => Reason, path => Dir}
   end.             

dir_tree(Dir)->case l(Dir) of
               {ok,L} -> lists:map(fun(A) -> dir_tree(Dir++"/"++A) end,L);
               [] -> {empty,Dir};
               {error,enotdir} -> Dir; 
                R -> R
               end.

chmod(A,B)->  file:change_mode(A,B).
chown(A,B)->  file:change_owner(A,B).
chown(A,B,C)->  file:change_owner(A,B,C).
chgrp(A,B)->  file:change_group(A,B).
chtime(A,B)->  file:change_time(A,B).
chtime(A,B,C)->  file:change_time(A,B,C).
path_to_list(Path)-> string:tokens(Path,"\\/").
    
%t()-> {date(),time()}.

app(App) -> application:ensure_all_started(App).

%p(Exp) -> io:format("~p~n",[Exp]).

s(Module) -> Module:start().

% compilation

strip()-> lists:map(fun(A)-> {beam_lib:info(A),beam_lib:strip(A)} end, lb()).
%strip()-> lists:map(fun(A)-> beam_lib:strip(A) end, lb()).

pmake_verbose(Options)-> %make:all().
         Start = erlang:system_time(),
         L=le(),
         Ref=erlang:make_ref(),
         {ok,Dir} = file:get_cwd(),
         Parent = self(),
         R=lists:map(fun(A)-> spawn(fun()->
                                   STime=erlang:system_time(), 
                                   Res = make:files([A],Options),
                                   Parent!#{ file=> A,
                                             date => {utc, calendar:universal_time()},
                                             dir  => Dir, 
                                             compilation_time => {mksec,(erlang:system_time()-STime) / 1000 }, 
                                             result => Res 
                                           } 
                                  end) , 
                                  receive R-> R end
                   end, 
                   L
                  ),
          %timer:sleep(1),        
          #{maketime => {mksec,(erlang:system_time()-Start) / 1000 }, results => R}.        
         %spawn(fun()->ref_recv_loop(Ref,length(L)) end).


pmake()->pmake([]).

pmake(Options)-> %make:all().
         Start = erlang:system_time(),
         L=le(),
         Ref=erlang:make_ref(),
         {ok,Dir} = file:get_cwd(),
         R=lists:map(fun(A)-> spawn(fun()->
                                   STime=erlang:system_time(), 
                                   Res = make:files([A],Options),
                                   logger:notice(#{ file=> A,
                                                    date => {utc, calendar:universal_time()},
                                                    dir  => Dir, 
                                                    compilation_time => {mksec,(erlang:system_time()-STime) / 1000 }, 
                                                    result => Res 
                                                  }) 
                                  end)  
                                  
                   end, 
                   L
                  ),
          
          #{maketime => {mksec,(erlang:system_time()-Start) / 1000 }, results => R}.        


ref_recv_loop(_,1)  -> true;
ref_recv_loop(Ref,N)->
 receive
  Msg    -> logger:notice(#{ msg => Msg})
%  {From,Ref,Msg}    -> logger:notice(#{ n=> N, ref => Ref, msg => Msg})
 end, 
 ref_recv_loop(Ref,N-1).

c()->    nice_view(os:cmd("erlc *.erl")).

mkdir(Dir)->
 file:make_directory(Dir).

l()-> file:list_dir(".").
l(Path)-> file:list_dir(Path).

lf(F2)->
 {ok,L} = l(),
  lists:foldl(F2,[],L).

lm(F1)->
 {ok,L} = l(),
  lists:map(F1,L).

lf(Path,F2)->
 {ok,L} = l(Path),
  lists:foldl(F2,[],L).

lm(Path,F1)->
 {ok,L} = l(Path),
  lists:map(F1,L).

le()-> lext(".erl").
la()-> lext(".app").
lc()-> lext(".config").
lt()-> lext(".txt").
lh()-> lext(".hrl").
lb()-> lext(".beam").
lb(Path)-> lext(Path,".beam").

lsrc()-> lext(".src").
lsrc(Path)-> lext(Path,".src").
lsrc(Path,F1)-> lext(Path,".src",F1).

lprj(Path,F1)-> lext(Path,".prj",F1).

src()-> lsrc("./",fun(A) ->
                        OldDir=file:get_cwd(),
                        file:set_cwd(A),
                        out("=> Enter to "++A),       
                        make:all(),
                        file:set_cwd(OldDir) 
                  end).

prj()-> lprj("./",fun(A) ->
                        OldDir=file:get_cwd(),
                        file:set_cwd(A),
                        out("=> Enter to "++A),       
                        %os:cmd("rebar make"),
                        F0= fetch_build_cmd(A),
                        F0(),
                        file:set_cwd(OldDir) 
                  end).

fetch_build_cmd(A) ->
 % L=consult("build_file"),
 % Cmd= proplists:get_value(A,L), 
 fun() -> nice_view(os:cmd("rebar make")) end.

lext(Ext)-> 
 lf(fun(A,Acc)->
     case ends(A,Ext) of
      true -> [A|Acc];
      _    -> Acc
     end 
    end).

lext(Path,Ext)-> 
 lf(Path,fun(A,Acc)->
     case ends(A,Ext) of
      true -> [A|Acc];
      _    -> Acc
     end 
    end).

lext(Path,Ext,F1)-> 
 lf(Path,fun(A,Acc)->
     case ends(A,Ext) of
      true -> [F1(A)|Acc];
      _    -> Acc
     end 
    end).

% example: lf2(fun(A,Ext)-> inside(A,Ext) end,"u").

lf2(F2,Ext)->
 lf(fun(A,Acc)->
     case F2(A,Ext) of
      true -> [A|Acc];
      _    -> Acc
     end 
    end).

% 
%ends(Name,Ext)-> 
%% io:format("~p ~p ~n",[length(Name)-length(Ext),string:str(Name,Ext)]),
% string:str(Name,Ext) == (length(Name) - length(Ext) + 1).

ends(Name,Ext)->
 %io:format("string:str =~p ",[string:str(Name,Ext)]),
 string:str(Name,Ext) > 0 andalso (string:str(Name,Ext) == length(Name) - length(Ext) +1).

starts(Name,Ext)-> 
% io:format("~p ~p ~n",[length(Name)-length(Ext),string:str(Name,Ext)]),
 string:str(Name,Ext) == 1.

inside(Name,Ext)-> 
% io:format("~p ~p ~n",[length(Name)-length(Ext),string:str(Name,Ext)]),
 string:str(Name,Ext) >= 1.

line_to_tuple(Line,Separators) -> list_to_tuple(string:tokens(Line,Separators)).

line_to_tuple(Line) -> line_to_tuple(Line," \t").

csv_line_to_tuple(Line) -> line_to_tuple(Line,",").
 
init_prompt()   ->
      %code:load_abs("./user_default"), 
      %shell:history(100),
      %shell:results(1000),
      %seq_trace:set_system_tracer(spawn(fun(A)-> recv_loop(fun(A)-> logger:notice(#{date => {date(), time() , erlang:system_time() } , msg =>A }) end) end)),
      msacc:start(),
      %error_handler:undefined_function(?MODULE,undefined_function,[info,f,[3]]),
      %error_handler:undefined_lambda(?MODULE,undefined_lambda,[info,2,3]),
      shell:prompt_func({?MODULE,hook}).

%undefined_function(M,F,Arg)->
%	logger:notice(#{module => M, function => F, args => Arg, reason => "undefined function", exports => M:module_info(exports)}).
%
%undefined_lambda(M,F,Arg)  ->
%	logger:notice(#{module => M, function => F, args => Arg, reason => "undefined lambda"}).

%return cluster or node statisctics
stats(Node)-> 
      #{node => Node, stats => rpc:call(Node,msacc,stats,[])}. 

stats()-> lists:map(fun(Node)-> #{node => Node, stats => rpc:call(Node,msacc,stats,[])} end,[node()|nodes()]).

% open/close time window for accumulation stats during given MSecs in Node
stats_time_window(Node,MSecs)-> 
      rpc:call(Node,msacc,start,[MSecs]). 

% open/close time window for accumulation stats during given MSecs in whole cluster
stats_time_window(MSecs)-> 
      lists:map(fun(Node)-> #{node => Node, stats => rpc:call(Node,msacc,stats,[MSecs])} end,[node()|nodes()]). 

%write system_information for local node to file Node-Host..node_information.txt
node_information()->
      system_information:to_file(atom_to_list(node())++"-"++?MODULE:name()++".node_information.txt").
       
%command prompt
hook(Arg)-> {ok,CWD}=file:get_cwd(),
            %io:format("Arg =~p ~n",[Arg]),
            %Tail=case get(history) of
            %      L when is_list(L) -> L;
            %      _                 -> []
            %     end,
            %push(history,[Arg|Tail]),
            %io:format("~p-~p-~p-~p-~p>",[{date(),time()},name(),ip(),node(),CWD]), % long format for prompt
            io:format("~p-~p-~p>",[ip(),node(),CWD]),
            "".

%get host time
clock()->{date(),time()}.
% get host ip            
ip()-> {ok,L}= inet:getif(),
   lists:foldl(fun({{127,0,0,1},_,_},Acc)  -> Acc;
                  ({A,_,_},Acc) -> [A|Acc] 
               end,[],L).

% get host name
name()->
 {ok,N}=inet:gethostname(),N.

%ip_stat()-> L = inet:stats(),
%  lists:foldl(fun(A,Acc)-> maps:put(A,inet:getstat(A),Acc) end,#{},L).       

%% lists operations
foldl(F2,Acc,List)-> lists:foldl(F2,Acc,List). 
map(F1,List)-> lists:map(F1,List).
reverse(List)-> lists:reverse(List).

at(H,[H|_],Acc)    -> 1+Acc;
at(What,[_|T],Acc) -> at(What,T,Acc+1);
at(What,[],Acc)    -> 0.

at(What,List)      -> at(What,List,0). 

%applyc(L) when is_list(L) -> lists:map(fun(NodeMFA)-> R=apply(NodeMFA),put(at(NodeMFA,L),R),R end,L).
applyc(L) when is_list(L) -> lists:map(fun(NodeMFARf)-> R=apply(NodeMFARf),put(at(NodeMFARf,L),R),R end,L).

% Rf is routing for adaptation one argument return for get(Net) to arbitrary list nedded for F, basicly it
% looks like fun(Var) -> [1,Var,some_arg] end, length of returned list shoul be as arity of NodeMF function
 
apply({Node,M,F,{at,Nth},Rf})  -> rpc:call(Node,M,F,Rf(get(Nth)));
apply({Node,M,F,{at,Nth}})  -> rpc:call(Node,M,F,[get(Nth)]);
apply({Node,M,F,A})   -> rpc:call(Node,M,F,A);
apply({M,F,{at,Nth}}) -> apply(M,F,[get(Nth)]);
apply({M,F,A})        -> apply(M,F,A).


% push Value to Key if it unique
push(Key,Value)-> L = case get(Key) of
                      R when is_list(R) -> R;
                      _ -> []
                      end,
                  case lists:member(Value,L) of
                   false -> put(Key,[Value| L]);
                   _     -> L
                  end.
                  
pop(Key) -> case get(Key) of
                      [R|Tail] -> put(Key,Tail),R;
                      _ -> []
            end.
         
from()->try get(from) of L when is_list(L) -> L catch _:_ -> [] end.
to()  ->try get(to)   of L when is_list(L) -> L catch _:_ -> [] end.
%cmd() ->try get(cmd)  of L when is_list(L) -> L catch _:_ -> [] end.
arg() ->try get(arg)  of L when is_list(L) -> L catch _:_ -> [] end.

%from(N)->L=from(),lists:nth(length(L)-N,L).
%to(N)  ->L=to(),  lists:nth(length(L)-N,L).
%arg(N) ->L=arg(), lists:nth(length(L)-N,L).

from(N)->L=from(),lists:nth(N,L).
to(N)  ->L=to(),  lists:nth(N,L).
arg(N) ->L=arg(), lists:nth(N,L).

history()-> case get(history) of
             L when is_list(L) -> L;
             _ -> []
             end.
             
history(N)-> case get(history) of
             L when is_list(L) -> lists:nth(N,L);
             _ -> []
             end.

cat(File)->{ok,Bin}=file:read_file(File),
            Bin.

cat(File,Delims)->{ok,Bin}=file:read_file(File),
                  string:tokens(unicode:characters_to_list(Bin),Delims).

cat(File,LDelims,FSep)->
                  lists:map(fun(A)->list_to_tuple(string:tokens(A,FSep)) end,cat(File,LDelims)).

lines(File)->{ok,F}=file:open(File,[read]),
             file:close(F).

stdout(Term) -> stdout(Term,"stdout.txt").

stdout(F0,FileName) when is_function(F0,0)-> 
           {ok,F} = file:open(FileName,[write,append]),
           io:format(F,"~p.~n",[F0()]),
           file:close(F); 

stdout(Term,FileName) -> {ok,F} = file:open(FileName,[write,append]),
                io:format(F,"~p.~n",[Term]),
                file:close(F). 

stdout(M,F,A) when is_atom(F) and is_atom(M) and is_list(A) -> 
           {ok,FD} = file:open("stdout.txt",[write]),
           io:format(FD,"~p.~n",[apply(M,F,A)]),
           file:close(FD). 

stdout(Node,M,F,A) when is_atom(F) and is_atom(M) and is_atom(Node) and is_list(A) -> 
           {ok,F} = file:open(atom_to_list(Node)++".stdout",[write]),
           io:format(F,"~p.~n",[rpc:call(Node,M,F,A)]),
           file:close(F). 

cp(From) -> cp(From,"/mnt").

cp(From,To) ->
 push(from,From),
 push(to,To), 
 case os:type() of
  {_,nt}       -> %nice_view(os:cmd("copy "  ++to_filename(From)++" "++to_filename(To)));
                  file:copy(to_filename(From),to_filename(To));

   _           -> nice_view(os:cmd("cp -r " ++to_filename(From)++" "++to_filename(To)))
 end.

mv(From,To) ->
  push(from,From),
  push(to,To),  
 file:rename(to_filename(From),to_filename(To)).

rm(Path)    -> 
  push(from,Path),
  file:delete(to_filename(Path)).

grep(What)  ->
  push(arg,What), 
  case os:type() of
  {_,nt} -> nice_view(os:cmd("find \"" ++to_filename(What)++"\" *"));

   _           -> nice_view(os:cmd("grep "++to_filename(What)++" -R *"))
 end.

find(What)  -> 
  push(arg,What),
  case os:type() of
  {_,nt} -> nice_view(os:cmd("find \"" ++to_filename(What)++"\" *"));

   _           -> nice_view(os:cmd("find . -name = "++to_filename(What)++""))
 end.

% run editor
ed(Files) when is_tuple(Files) ->
 push(arg,Files), 
 map(fun(A) -> ed(A) end, tuple_to_list(Files));

ed(File) ->
 push(arg,File),
 case {get_env("OS"), get_env("XDG_SESSION_TYPE"),os:type()} of
  {"Windows_NT",_,_} -> %os:cmd("copy "  ++to_filename(From)++" "++to_filename(To));
                      spawn( fun()-> os:cmd("notepad " ++ to_filename(File)) end);
  
  {_,_,{unix,darwin}}    -> spawn( fun()-> os:cmd("textedit " ++to_filename(File)) end);
  {_,"x11",{unix,_} }    -> spawn( fun()-> os:cmd("mousepad " ++to_filename(File)) end)

 end.

% source files formatter
tidy(Path)-> erl_tidy:dir(Path).
tidy()-> tidy(".").

%create makefile
create_makefile() -> 
        % it need to check existence of Emakefile and rename it if needed
        mv("Emakefile","Emakefile.old."++integer_to_list(erlang:system_time(),32)),
	Content=
	{'./src/*', 
 	[debug_info, 
	{outdir, "./ebin"},  
	{i, "./include/."}
 	]
	},
 	
        {ok,F} = file:open("Emakefile",[write]),
	 io:format(F,"~p~n.",[Content]),
	 file:close(F).

add_history(Item) -> 
	Content = 
	#{ date  => calendar:universal_time(),
	   works => Item 
	 },
 	
        {ok,F} = file:open("HISTORY",[write,append]),
	 io:format(F,"~p.~n~n",[Content]),
	 file:close(F).

%create application file
create_application(App)->
	AppStr=atom_to_list(App),

	Content={application, App,
 	[{description, "A "++AppStr++" application"},
	  {vsn, "0.0.0"},
	  {registered, []},
	  {mod, {list_to_atom(AppStr++ "_app"), []}},
	  {applications,
	   [kernel,
 	   stdlib
 	  ]},
 	 {env,[]},
 	 {modules, []},
	
 	 {maintainers, []},
 	 {licenses, ["Apache 2.0"]},
 	 {links, []}
 	]},
 	
        {ok,F} = file:open(AppStr++".app",[write]),
	 io:format(F,"~p~n.",[Content]),
	 file:close(F).

% archive operations

zip_ls(Zip)-> zip:list_dir(Zip).

zip(Zip,FileList)-> zip:zip(Zip,FileList).
zip(FileorDir)-> zip:zip(FileorDir++".zip",[FileorDir]).
zip()->
 {ok,CWD} = file:get_cwd(),
  [Zip|_] = lists:reverse(string:tokens(CWD,"/\\")),
   file:set_cwd(".."),
   zip(Zip),
  out("../"++Zip++".zip created\n"),
  file:set_cwd(CWD).
 
unzip(Zip)-> zip:unzip(Zip).

untgz(Arhive)-> nice_view(os:cmd("tar xvfz "++Arhive)).
untar(Arhive)-> nice_view(os:cmd("tar xvf "++Arhive)).

%% http operations
-define(AGENTS,
["Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko", % IE 11
 "Mozilla/5.0 (Windows NT 6.1; rv:68.0) Gecko/20100101 Firefox/68.0", % Fiefox
 "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.100 Safari/537.36 OPR/62.0.3331.72" % OPERA
]
).

random_agent()-> 
N=random:uniform(length(?AGENTS)),
try lists:nth(N,?AGENTS) of
 R->R
 catch
  _:_ -> [H|_] = ?AGENTS, H
end.

http(Method,URL)->
 push(arg,{Method,URL}),
 lists:map(fun(A)->application:ensure_all_started(A) end, [ssl,crypto,inets]),
 {ok,{Stat,Headers,Body}}=
      httpc:request(Method,{URL,[{"User-Agent",random_agent()}]},
                             [{timeout,5000},{autoredirect,true}],
                             [{body_format,binary}]), 
 Body. 

http_fetch(URL)->
 push(arg,URL), 
 [FileName|_] = lists:reverse(string:tokens(URL,"/")),
 http_fetch(URL,FileName,fun(FN)->post_transform(FileName) end).

http_fetch(URL,FileName,F1)->
 push(arg,{URL,FileName,F1}), 
 io:format("~p will save as ~p ~n",[URL,FileName]),
 F=open_file(FileName),
 file:write(F,http(get,URL)),
 file:close(F),
 F1(FileName).

http_tests()->
 http_test({
 "https://github.com/d-podkorytov/erl2/archive/master.zip",
 "https://github.com/d-podkorytov/letsencrypt-erlang/archive/master.zip",
 "https://github.com/d-podkorytov/one_dns_msg/archive/master.zip",
 "https://github.com/d-podkorytov/veos/archive/master.zip"
 }).

http_test(URLs) when is_tuple(URLs)->
 lists:map(fun(URL)->http_test(URL) end, tuple_to_list(URLs));

http_test(URL) when is_list(URL)->
http_fetch(URL,
           transform_name(URL),
           fun(FN)->post_transform(FN) end
           ).

http_test()->
http_fetch("https://codeload.github.com/d-podkorytov/tssh/zip/master",
           transform_name("https://codeload.github.com/d-podkorytov/tssh/zip/master"),
           fun(FN)->post_transform(FN) end
           ).

transform_name(URL)->
 try string:tokens(URL,"/") of
  ["https:","codeload.github.com",Authtor,Proj,Zip,Master] -> Authtor++"-"++Proj++"-"++Master++"."++Zip; 
  ["https:","github.com",Authtor,Proj,Zip,Master] -> Authtor++"-"++Proj++"-"++Master   
 catch
  _:_ -> io:format("Unknown sources site ~p using default file name as index.html ~n",[URL]),
         "index.html"
 end.  

post_transform(FileName)->
[Ext|_] = lists:reverse(string:tokens(FileName,"./\\")),
case Ext of
 "zip" -> unzip(FileName);
 "ZIP" -> unzip(FileName);
 "tgz" -> untgz(FileName);
 "TGZ" -> untgz(FileName);
 "tar" -> untar(FileName);
 "TAR" -> untar(FileName);
  E -> io:format("unknown extension do not know how to handle ~p file ~n",[E])
end.

% choose build system by directory extension
do_build(DirName)->
[Ext|_] = lists:reverse(string:tokens(DirName,".")),
case Ext of
 "src"    -> OldDir=file:get_cwd(),
             file:set_cwd(DirName),
             out("=> Enter to "++DirName),       
             make:all(),
             file:set_cwd(OldDir);
             
 "rebar"  -> OldDir=file:get_cwd(),
             file:set_cwd(DirName),
             out("=> Enter to "++DirName),       
             nice_view(os:cmd(". ./rebar get-deps && . ./rebar make")),
             file:set_cwd(OldDir);
             
 "rebar3" -> OldDir=file:get_cwd(),
             file:set_cwd(DirName),
             out("=> Enter to "++DirName),       
             nice_view(os:cmd(". ./rebar3 get-deps && . ./rebar3 make")),
             file:set_cwd(OldDir);
             
 "make"   -> OldDir=file:get_cwd(),
             file:set_cwd(DirName),
             out("=> Enter to "++DirName),       
             nice_view(os:cmd("make")),
             file:set_cwd(OldDir);
             
 "go"     -> OldDir=file:get_cwd(),
             file:set_cwd(DirName),
             out("=> Enter to "++DirName),       
             nice_view(os:cmd("go build")),
             file:set_cwd(OldDir);

  E -> io:format("unknown extension do not know how to build ~p directory ~n",[E])
end.
  
%% file operations
open_file(FileName)     -> {ok,F} = file:open(to_filename(FileName),[write]),F.
close_file(File)        -> file:close(File).
consult_file(FileName)  -> {ok,L} = file:consult(to_filename(FileName)),L.
read_file(FileName)     -> {ok,L} = file:read_file(to_filename(FileName)),L.
format_file(File,Mask,L)-> io:format(File,Mask,L).
out(Term) ->  io:format("~p~n",[Term]).
outs(Term)->  io:format("~ts~n",[Term]).
out(File,Term) ->  io:format(File,"~p~n",[Term]).
outs(File,Term)->  io:format(File,"~ts~n",[Term]).
write_file(File,Bin)    -> file:write(File,Bin).

%% function calls
cmd(Cmd)                 ->
 push(arg,Cmd), 
 nice_view(os:cmd(Cmd)).

cmd(Input,Cmd)                 ->
 Cmd1 = "echo "++Input++"|"++Cmd,
 push(arg,Cmd1), 
 nice_view(os:cmd(Cmd1)).

%cmd(Node,Arg)            ->
% push(arg,{Node,Arg}), 
% rpc:call(Node,os,cmd,[Arg]).

call(Node,Mod,Fun,Arg)   -> rpc:call(Node,Mod,Fun,Arg).

mcall(Nodes,Mod,Fun,Arg) -> rpc:multicall(Nodes,Mod,Fun,Arg).
mcall(Mod,Fun,Arg)       -> rpc:multicall(Mod,Fun,Arg).
 

to_filename(A) when is_atom(A) -> atom_to_list(A);
to_filename(A) when is_binary(A) -> unicode:characters_to_list(A);
to_filename(A) when is_integer(A) -> integer_to_list(A);
to_filename(A) -> A.

%% run script
eval(Path)  ->
 push(arg,Path), 
 file:eval(Path).

eval(Node,Path) -> rpc:call(Node,file,eval,[Path]).

mount(Dev)  ->
 push(arg,Dev), 
 mount("/dev/"++to_filename(Dev),"/mnt").

mount(Dev,Mnt)  ->
                 push(from,Dev),
                 push(to,Mnt),  
                 case os:type() of
                 {unix,_} -> nice_view(os:cmd("mount "++to_filename(Dev)++" "++to_filename(Mnt)));
                 %{_,  nt} -> string:tokens(os:cmd("dir"),"\n");
                 R  -> {R,todo,mount}
                end.
                
umount() -> umount("/mnt").

umount(Mnt)  ->
 push(arg,Mnt), 
 case os:type() of
                 {unix,_} -> nice_view(os:cmd("umount "++to_filename(Mnt)));
                 %{_,  nt} -> string:tokens(os:cmd("dir"),"\n");
                 R  -> {R,todo,umount}
                end.

df()         -> case os:type() of
                 {unix,_} -> nice_view(os:cmd("df -h"));
                 {_,  nt} -> string:tokens(os:cmd("dir"),"\n");
                 R  -> {R,todo,df}
                end.

df(Node)     ->
            push(arg,Node),
            case os:type() of
                 {unix,_} -> nice_view(rpc:call(Node,os,cmd,["df -h"]));
                 {_,  nt} -> nice_view(rpc:call(Node,os,cmd,["dir"]));
                 R  -> {R,todo,df}
                end.

du()         -> lists:map(fun([H|Tail])-> {list_to_integer(H),Tail} end,lists:map(fun(A)-> string:tokens(A,"\t")end,string:tokens(os:cmd("du *"),"\n"))).

netstat()    -> nice_view(os:cmd("netstat -an")).
netstat(Node)->
 push(arg,Node), 
 nice_view(rpc:call(Node,os,cmd,["netstat -an"])).

nslookup(Name,In,A,Server,Port)      -> inet_res:nslookup(Name,In,A,[{Server,Port}]).
nslookup(Node,Name,In,A,Server,Port) -> rpc:call(Node,inet_res,nslookup,[Name,In,A,[{Server,Port}]]).

nslookup(#{name := Name, in := In,a := A,server := Server,port := Port}) -> 
	inet_res:nslookup(Name,In,A,[{Server,Port}]);

nslookup(Name)->nslookup(Name,in,a,{1,1,1,1},53).

nslookup()->nslookup("ya.ru",in,a,{1,1,1,1},53).
dig()     ->nslookup("ya.ru",in,a,{127,0,0,1},53).

dig(Name)->nslookup(Name,in,a,{127,0,0,1},53).

ps()         -> nice_view(os:cmd("ps aux")).
ps(Node)     -> push(arg,Node),nice_view(rpc:call(Node,os,cmd,["ps aux"])).
pinfo(Pid)   -> rpc:pinfo(Pid).
pinfo(Pid,Item) -> rpc:pinfo(Pid,Item).

% ps with F1 as predicate for filtration
psf(F1)     -> lists:map(fun(A,Acc)-> try F1(A) of
                                       true -> [A|Acc];
                                       _    ->    Acc
                                      catch
                                       Err:Reason -> {Err,Reason,A,F1} 
                                      end 
                             
                         end,[],
                         string:tokens(os:cmd("ps aux"),"\n")
                        ).
%% ps with grep
psg(Arg)     ->
 push(arg,Arg), 
 string:tokens(os:cmd("ps aux | grep "++Arg),"\n").
%% ps with grep -n
psgn(Arg)    -> push(arg,Arg),string:tokens(os:cmd("ps aux | grep -v "++Arg),"\n").
      
%% apply function of one argument to each line of text file File in map style
map_file_lines(FileName,F1) -> {ok,File}=file:open(FileName,[read]),
                               map_lines_loop(File,F1).

%% apply function of one argument to each line of text file File in foldl style
fold_file_lines(FileName,F2,Acc) -> {ok,File}=file:open(FileName,[read]),
                               fold_lines_loop(File,F2,Acc).
%% map loop for text file                               
map_lines_loop(File,F1)->
 case file:read_line(File) of
  eof -> ok;
  R   -> %io:format("R=~p~n",[R]),
         F1(R),
         map_lines_loop(File,F1)  
 end.

%% foldl loop for text file                               
fold_lines_loop(File,F2,Acc)->
 case file:read_line(File) of
  eof -> ok;
  R   -> %io:format("R=~p~n",[R]),
         fold_lines_loop(File,F2,F2(R,Acc))  
 end.

%% safe call apply(M,F,A).
try_mfa({M,F,A})-> try apply(M,F,A) of
             R->R
             catch
              Err:Reason-> {Err,Reason,{M,F,A}}
             end.  

%% safe call apply(M,F,A).
try_nmfa({N,M,F,A})-> try rpc:call(N,M,F,A) of
             R->R
             catch
              Err:Reason-> {Err,Reason,{M,F,A}}
             end.  

%% safe call lambda function without arguments 
try_f0(F0)-> try F0() of
             R->R
             catch
              Err:Reason-> {Err,Reason,F0}
             end.  

%% safe call lambda function with one argument
try_f1(F1,Arg)-> try F1(Arg) of
             R->R
             catch
              Err:Reason-> {Err,Reason,F1,Arg}
             end.  
%% help
help()->
 io:format("~p Exports:~n",[?MODULE]), 
 foldl(fun({F,Arity},Acc) -> io:format("~p/~p ",[F,Arity]),"" end, [],user_default:module_info(exports)).

help(Word) when is_atom(Word)->help(atom_to_list(Word));

help(Word) when is_list(Word)->
 io:format("~p Exports with word :~p ~n",[?MODULE,Word]), 
 foldl(fun({F,Arity},Acc) -> case inside(atom_to_list(F),Word) of
                                true -> io:format("~p/~p ",[F,Arity]),
                                        [{F,Arity}|Acc];
                                _ ->    Acc 
                             end   
       end, 
 [],
 ?MODULE:module_info(exports)).

%% build functions
build()-> ok.
download_deps()-> ok.
upload()-> ok.

exit()->  
 init:stop(self()).

%% add pathes for load modules
erl_add_patha(PathesTuple) when is_tuple(PathesTuple) -> 
 map(fun(Path)-> code:add_patha(Path) 
     end,
     tuple_to_list(PathesTuple)
    );
erl_add_patha(Path) when is_list(Path) -> code:add_patha(Path).

%% get pathes for load modules
erl_get_path()-> code:get_path().

%% get exports tree for all modules
exports()->exports(erl_get_path()).

%% get exports tree for all modules for given pathes list
exports(Pathes)-> map(fun(Path)->
                  map(fun(A) -> [ModStr|_] = string:tokens(A,"."),
                                 Mod= list_to_atom(ModStr),
                                {Path++"/"++A,Mod,Mod:module_info(exports)} 
                      end,
                  lb(Path)
                   ) 
                end, 
                Pathes
               ).
               
%% print global export's tree to text file               
system_export_to_file()->
 F=open_file("system_exports.txt"),
 out(F,exports()),
 close_file(F).

%% print export's tree to text file for given pathes list               
 export_to_file(Pathes)->
 F=open_file("exports.txt"),
 out(F,exports(Pathes)),
 close_file(F).

% tracing

tracers()-> lists:map(fun(A)-> try tracer_node(A) of R->R catch Err:Reason -> {Err,Reason,A} end end, [ node()| nodes() ]).
tracer_add()-> lists:map(fun(A)-> tracer_add(A) end, nodes() ).

tracer_off()-> dbg:stop_clear(),dbg:stop().

tracer_node(Node)->
      dbg:n(Node), 
      dbg:tracer(Node,all,c).

tracer_add(Node)->
      dbg:n(Node).

trace_file(FileName)-> dbg:trace_client(file,FileName).
%trace_ip(Port)-> dbg:tracer(dbg:trace_client(ip,Port),send).
      % dbg:trace_client(file,pid_to_list(self())++"-trace.log")
t()-> {ok,Pid}=dbg:tracer(),
      %P=process_loop(fun(A) -> out({tracer,A}) end),        
      dbg:p(self(),send).

%t(Node)-> rpc:call(Node,dbg,tracer,[]),       
%          rpc:call(Node,dbg,p,[self(),send]).

t(Node)-> rpc:call(Node,dbg,tracer,[]),
          dbg:tracer(),
          P=process_loop(fun(A) -> out(A) end),
          dbg:p(P,send),       
          rpc:call(Node,dbg,p,[P,send]).
                  
tracer_on()->
 dbg:tracer(), %% Start the default trace message receiver
 dbg:p(all, c). %% Setup call (c) tracing on all processes

tracer_new()->
 dbg:tracer(),
 dbg:p(new,c).

trace(Mod,Fun)               ->dbg:tp(Mod, Fun, cx). %% Setup an exception return trace (x) on lists:seq
trace(Node,Mod,Fun)          ->dbg:n(Node),
                               dbg:tp(Node,Mod, Fun, cx). %% Setup an exception return trace (x) on lists:seq
trace(Mod) when is_atom(Mod) ->dbg:tp({Mod,'_','_'}, cx);

trace(Pid) when is_pid(Pid)  ->dbg:p(pid_to_list(Pid),c).

trace_flag(Mod,Flag)    ->dbg:tp({Mod,'_','_'}, Flag).
trace_flag(Mod,Fun,Flag)->dbg:tp({Mod,Fun,'_'}, Flag).

trace_off(Mod)    ->dbg:ctp({Mod,'_','_'}).
trace_off(Mod,Fun)->dbg:ctp({Mod,Fun,'_'}).

tracer_add_node(Node)->dbg:n(Node).

tracer(example)->
 "tracer_on(),trace(lists,seq),lists:seq(1,10),trace_off(lists,seq),lists:seq(1,10).";                 

tracer(help)->
 ?HELP("tracer_on()","Start tracer"),
 ?HELP("tracer_off()","Stop tracer"), 

 ?HELP("trace(Mod,Fun)","Trace all Mod:Func(...) calls"),
 ?HELP("trace(Module)","Trace all Module calls"),
 ?HELP("trace(Pid)","TODO"),

 ?HELP("trace_flag(Mod,Flag)","Set trace flag for module Mod"),
 ?HELP("trace_flag(Mod,Fun,Flag)","Set trace flag for Mod:Fun calls"),

 ?HELP("trace_off(Module)","Turn off tracing for Module"),
 ?HELP("trace_off(Mod,Fun)","Turn off tracing Mod:Fun calls"),

 ?HELP("tracer_add_node(Node)","Add node for tracing"),

 ?HELP("tracer(example)","Show using of tracer ").                 

process_loop(F1) -> spawn(fun()-> recv_loop(F1) end).

recv_loop(F1)->
 receive
  Msg -> try F1(Msg) of R->R 
         catch Err:Reason -> io:format("recv_loop catch ~p:~p~n",[Err,Reason]) 
         end 
 end,
 recv_loop(F1).

recv_loop(Node,Mod,Fun)->
 receive
  Msg -> try rpc:async_call(Node,Mod,Fun,[Msg]) of R->R 
         catch Err:Reason -> io:format("recv_loop catch ~p:~p~n",[Err,Reason]) 
         end 
 end,
 recv_loop(Node,Mod,Fun).

% get messages in loop and call given function (with arity 4) from rpc module
% RPC_FUC4 can be  
% [ {block_call,4},
%   {server_call,4},
%   {eval_everywhere,4},
%   {multicall,4},
%   {async_call,4},
%   {cast,4},
%   {call,4}
% or any function of such module
% ]
% Transformer is function/1 for mapping incoming messages to RPC_FUN/4 
% arguments requiremens, so it shouldbe list with four arguments  
% or with arity of function from rpc module
recv_loop(Node,RPC_FUN4,Mod,Fun,Transformer)->
 receive
  Msg -> try apply(rpc,RPC_FUN4,[Node,Mod,Fun,Transformer(Msg)]) of 
          R->R 
         catch Err:Reason -> io:format("recv_loop catch ~p:~p~n",[Err,Reason]) 
         end 
 end,
 recv_loop(Node,RPC_FUN4,Mod,Fun,Transformer).

processes(help)->
  ?HELP("process_loop(F1)","Start background endless loop with message hanler such as fun(Msg)-> ... end"),
  ?HELP("recv_loop(F1)","Same as above but it starts in foregroud"),
  ?HELP("recv_loop(Node,Mod,Fun,Transformer)","Foreground endless loop , it reads messages and asyncronically handle it inside given node"),
  ?HELP("try_nmfa({Node,Mod,Fun,Args})"," safe call in try apply(Node,Module,Fun,Args)"),
  ?HELP("","").

files(help)->
  ?HELP("",""),
  ?HELP("","").


environment(help)->
  ?HELP("",""),
  ?HELP("","").

build(help)->
  ?HELP("",""),
  ?HELP("","").

communications(help)->
  ?HELP("",""),
  ?HELP("","").

% Communications

ask({pid,Pid},_,F0) -> Pid!F0();
ask({module,Mod},Socket,F0) -> Mod:send(Socket,F0()).

wait_reply(Timeout,F1)->
 receive
  Msg->F1(Msg)
 after Timeout -> timeout
 end.

connect({pid,_},_) -> ok;
connect({module,Module},Args) -> apply(Module,connect,Args).

close({module,Module},Socket)-> Module:close(Socket);
close(_,_) -> ok.

ask_wait(Transport,Socket,F0,Timeout,PostF1) ->
 ask(Transport,Socket,F0),
 wait_reply(Timeout,PostF1). 

session(Transport,Args,Socket,F0,Timeout,PostF1)->
     Socket=connect(Transport,Args),
     R=ask_wait(Transport,Socket,F0,Timeout,PostF1),
     close(Transport,Socket),
     R.

session_apply(Transport,Args,Socket,Timeout)->
     Socket=connect(Transport,Args),
     %R=lists:map(fun({{},{}})-> end, Asks),
     close(Transport,Socket),
     'R'.

publish() -> todo.

backup_system() -> todo.
backup_user() -> todo.

services()->
  case os:type() of
  {_,nt}       -> nice_view(os:cmd("sc queryex "));

   _           -> nice_view(os:cmd("service --status-all"))
 end.

os_info()-> #{os_type => os:type() , 
              version => os:version() , 
              %uname => uname() , 
              %uptime => uptime(), 
              ip => ip() , 
              host => name() , 
              %route => route() , 
              machtype => mach_type()}.

uname()->
   case os:type() of
  {_,nt}       -> nice_view(os:cmd("version"));

  {unix,_}     -> nice_view(os:cmd("uname -a"));
  R -> {R,todo, uname}
 end.

uptime()->
   case os:type() of
  {_,nt}       -> nice_view(os:cmd("uptime"));

  {unix,_}     -> nice_view(os:cmd("uptime"));
  R -> {R,todo, uptime}
 end.

route()->
   case os:type() of
  {_,nt}       -> nice_view(os:cmd("route print"));

  {unix,_}     -> nice_view(os:cmd("route -n| grep -v Kernel | grep -v Destination"));
  R -> {R,todo, route}
 end.

mach_type()->
   case os:type() of
  {_,nt}       -> os_env("PROCESSOR_IDENTIFIER")++"*"++os_env("NUMBER_OF_PROCESSORS");
  {unix,_}     -> nice_view(cmd("uname -a")); % -om
  R -> {R,todo, route}
 end.

% CLUSTER
world()      -> net_adm:world().
names()      -> {ok,L}=net_adm:names(),lists:map(fun({Name,_})-> Name end,L).
ping(Node)   -> net_adm:ping(Node).
ping()       -> lists:map(fun(A)-> {A,ping(A)} end, [node()|nodes()]).
allow(Nodes) -> net_kernel:allow(Nodes).
world_list(Nodes) -> net_adm:world_list(Nodes).
world_list() -> L=net_adm:world_list(),
                lists:map(fun(Node)-> Node end,L).

% communications by IP stack  
net_connect(gen_udp,Addr,Port) ->
{ok, S} = gen_udp:open(0, [binary, {active, true}]),                      
 try gen_udp:connect(S,Addr,Port) of
  ok    -> {gen_udp,S};
  R     ->  R
 catch
  Err:Reason -> {gen_udp,{Err,Reason},Addr,Port}
 end;

net_connect(Mod,Addr,Port) ->
 try Mod:connect(Addr,Port,[{active,true},binary]) of
 {ok,S} -> {Mod,S};
  R     ->  R
 catch
  Err:Reason -> {Mod,{Err,Reason},Addr,Port}
 end.

net_send(Mod,S,Bin) -> Mod:send(S,Bin).

net_actor(Mod,Addr,Port,F0) ->
  {Mod,S} = net_connect(Mod,Addr,Port),
  ok = Mod:controlling_process(S,spawn(F0)),
  S.

net_seq(Mod,Addr,Port,F0,SeqList) ->
  S = net_actor(Mod,Addr,Port,F0),
  map(fun(A)-> ok = net_send(Mod,S,A) end, SeqList),
  net_close(Mod,S).

net_close(Mod,S)-> Mod:close(S).

udp_test()->
 net_seq(gen_udp,{77,88,8,3},53,fun()-> process_loop(fun(Msg)-> out(Msg) end) end,[<<0,0,0,0,0,0,0,0,0>>]).

tcp_test()->
 net_seq(gen_tcp,"21.ru",80,fun()-> process_loop(fun(Msg)-> out(Msg) end) end,[<<"GET /\n">>]).

net()-> #{net   => net:if_names(),
          inet  => inet:getifaddrs(),
          nodes => [node()|nodes()]  
         }.
   