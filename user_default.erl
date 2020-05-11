-module(user_default).
-compile(export_all).

-define(EDITOR,"ed").

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
home()-> 
  case os:getenv("HOME") of
   false -> os:getenv("USERPROFILE");% user's root for Windows
   R0->R0
 end.
 
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
       
a(Key) -> case proplists:get_value(Key,aliases()) of
          L when is_list(L)   -> lists:map(fun({Mod,Fun,Arg})         -> nice_view(apply(Mod,Fun,Arg));
                                              ({cluster,Mod,Fun,Arg}) -> lists:zip([node()|nodes()],nice_view(mcall(Mod,Fun,Arg)));
                                              ({Nodes,Mod,Fun,Arg}) when is_list(Nodes) -> 
                                                                         lists:zip([node()|nodes()],nice_view(mcall(Nodes,Mod,Fun,Arg)));  
                                              ({Node,Mod,Fun,Arg})    -> {Node,nice_view(rpc:call(Node,Mod,Fun,Arg))};
                                              (A) -> {"can not evaluate",A}
                                           end         
                                           ,L); 
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

scp(From,To,Port)  -> os:cmd("scp -P "++integer_to_list(Port)++" "++From++" "++To).

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

from({file,Name})->{ok,F}=file:open(Name,[read]),F;
from(pid)->receive Msg->Msg after 2000-> timeout end.

to({file,Name})  ->{ok,F}=file:open(Name,[write]),F.
 
t()-> {date(),time()}.

app(App) -> application:ensure_all_started(App).

%p(Exp) -> io:format("~p~n",[Exp]).

s(Module) -> Module:start().

make()-> make:all().
c()->    string:tokens(os:cmd("erlc *.erl"),"\n").

mkdir(Dir)->
 file:make_directory(Dir).

l()-> file:list_dir(".").
l(Path)-> file:list_dir(Path).

lf(F2)->
 {ok,L} = l(),
  lists:foldl(F2,[],L).

lf(Path,F2)->
 {ok,L} = l(Path),
  lists:foldl(F2,[],L).

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
 fun() -> os:cmd("rebar make") end.

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
ends(Name,Ext)-> 
% io:format("~p ~p ~n",[length(Name)-length(Ext),string:str(Name,Ext)]),
 string:str(Name,Ext) == (length(Name) - length(Ext) + 1).

starts(Name,Ext)-> 
% io:format("~p ~p ~n",[length(Name)-length(Ext),string:str(Name,Ext)]),
 string:str(Name,Ext) == 1.

inside(Name,Ext)-> 
% io:format("~p ~p ~n",[length(Name)-length(Ext),string:str(Name,Ext)]),
 string:str(Name,Ext) >= 1.
 
init_prompt()   ->
      %code:load_abs("./user_default"), 
      shell:history(100),
      shell:results(1000), 
      shell:prompt_func({?MODULE,hook}).

hook(Arg)-> {ok,CWD}=file:get_cwd(),
            %io:format("~p-~p-~p-~p-~p>",[{date(),time()},name(),ip(),node(),CWD]), % long format for prompt
            io:format("~p-~p-~p>",[ip(),node(),CWD]),
            "".
clock()->{date(),time()}.
            
ip()-> {ok,L}= inet:getif(),
   lists:foldl(fun({{127,0,0,1},_,_},Acc)  -> Acc;
                  ({A,_,_},Acc) -> [A|Acc] 
               end,[],L).

name()->
 {ok,N}=inet:gethostname(),N.

%ip_stat()-> L = inet:stats(),
%  lists:foldl(fun(A,Acc)-> maps:put(A,inet:getstat(A),Acc) end,#{},L).       

%% lists operations
foldl(F2,Acc,List)-> lists:foldl(F2,Acc,List). 
map(F1,List)-> lists:map(F1,List).
reverse(List)-> lists:reverse(List).

%% archive operations

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

untgz(Arhive)-> os:cmd("tar xvfz "++Arhive).
untar(Arhive)-> os:cmd("tar xvf "++Arhive).

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
 lists:map(fun(A)->application:ensure_all_started(A) end, [ssl,crypto,inets]),
 {ok,{Stat,Headers,Body}}=
      httpc:request(Method,{URL,[{"User-Agent",random_agent()}]},
                             [{timeout,5000},{autoredirect,true}],
                             [{body_format,binary}]), 
 Body. 

http_fetch(URL)-> 
 [FileName|_] = lists:reverse(string:tokens(URL,"/")),
 http_fetch(URL,FileName,fun(FN)->post_transform(FileName) end).

http_fetch(URL,FileName,F1)-> 
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
             os:cmd(". ./rebar get-deps && . ./rebar make"),
             file:set_cwd(OldDir);
             
 "rebar3" -> OldDir=file:get_cwd(),
             file:set_cwd(DirName),
             out("=> Enter to "++DirName),       
             os:cmd(". ./rebar3 get-deps && . ./rebar3 make"),
             file:set_cwd(OldDir);
             
 "make"   -> OldDir=file:get_cwd(),
             file:set_cwd(DirName),
             out("=> Enter to "++DirName),       
             os:cmd("make"),
             file:set_cwd(OldDir);
             
% "cmake"  -> ok;
 "go"     -> OldDir=file:get_cwd(),
             file:set_cwd(DirName),
             out("=> Enter to "++DirName),       
             os:cmd("go build"),
             file:set_cwd(OldDir);
% "ant"    -> ok;
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
cmd(Arg)                 -> os:cmd(Arg).
cmd(Node,Arg)            -> rpc:call(Node,os,cmd,[Arg]).
call(Node,Mod,Fun,Arg)   -> rpc:call(Node,Mod,Fun,Arg).
mcall(Nodes,Mod,Fun,Arg) -> rpc:multicall(Nodes,Mod,Fun,Arg).
mcall(Mod,Fun,Arg)       -> rpc:multicall(Mod,Fun,Arg).
 
cp(From,To) -> file:copy(to_filename(From),to_filename(To)).
mv(From,To) -> file:rename(to_filename(From),to_filename(To)).
rm(Path)    -> file:delete(to_filename(Path)).

to_filename(A) when is_atom(A) -> atom_to_list(A);
to_filename(A) when is_binary(A) -> unicode:characters_to_list(A);
to_filename(A) when is_integer(A) -> integer_to_list(A);
to_filename(A) -> A.

%% run script
eval(Path)  -> file:eval(Path).
eval(Node,Path) -> rpc:call(Node,file,eval,[Path]).

ed(Path)        -> os:cmd(?EDITOR++" "++Path).

df()         -> string:tokens(os:cmd("df -h"),"\n").
df(Node)     -> string:tokens(rpc:call(Node,os,cmd,["df -h"]),"\n").

du()         -> lists:map(fun([H|Tail])-> {list_to_integer(H),Tail} end,lists:map(fun(A)-> string:tokens(A,"\t")end,string:tokens(os:cmd("du *"),"\n"))).
netstat()    -> string:tokens(os:cmd("netstat -an"),"\n").
netstat(Node)-> string:tokens(rpc:call(Node,os,cmd,["netstat -an"]),"\n").

ps()         -> string:tokens(os:cmd("ps aux"),"\n").
ps(Node)     -> string:tokens(rpc:call(Node,os,cmd,["ps aux"]),"\n").
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
psg(Arg)     -> string:tokens(os:cmd("ps aux | grep "++Arg),"\n").
%% ps with grep -n
psgn(Arg)    -> string:tokens(os:cmd("ps aux | grep -v "++Arg),"\n").
      
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
 io:format("Exports:~n",[]), 
 foldl(fun({F,Arity},Acc) -> io:format("~p/~p ",[F,Arity]),"" end, [],user_default:module_info(exports)).

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

                