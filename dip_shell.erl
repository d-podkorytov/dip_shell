% Installer for Dip Shell

-module(dip_shell).
-compile(export_all).

deinstall()->
 HOME=case os:getenv("HOME") of
   false -> os:getenv("USERPROFILE");% user's root for Windows
   R0->R0
 end,
 io:format("User home=~p~n",[HOME]),                                                                
 io:format("Remove the following line as the first line in your ~s/.erlang file in your home directory.",[HOME]),
 io:format("code:load_abs(\"~s/user_default\"),user_default:init_prompt().",[HOME]).

install()->
  user_default:init_prompt(),
% io:format("~s~n~n",["Add the following line as the first line in your .erlang file in your home directory."]),
 HOME=case os:getenv("HOME") of
   false -> os:getenv("USERPROFILE");% user's root for Windows
   R0->R0
 end,
 io:format("HOME=~p~n",[HOME]),
 try file:rename(HOME++"/.erlang ",HOME++"/.erlang.old") of
  {error,enoent} -> io:format("file ~s/.erlang was created  ~n",[HOME]);

  ok-> %io:format("R=~p",[R]),
      io:format("new file ~s/.erlang was created ~n",[HOME]),
      io:format("old file ~s/.erlang will be moved to ~s/.erlang.old ~n",[HOME,HOME])
  catch
  _:_ -> ""
 end,
  
 {ok,F} = file:open(HOME++"/.erlang",[write]),
 {ok,CWD} = file:get_cwd(),
 io:format(F,"~s~n",["code:load_abs(\""++CWD++"/user_default\"),user_default:init_prompt(),user_default:welcome()."]),
 file:close(F),

 {ok,F1} = file:open(HOME++"/.dip_aliases",[write]),

 lists:map(fun(A)->io:format(F1,"~s~n",[A]) end,[
 "{os_date,{os,cmd,[\"date\"]}}.",
 "{nodes_date,{cluster,user_default,local_time,[]}}.",
 "{welcome,[{cluster,user_default,local_time,[]},{cluster,erlang,node,[]}]}."
 ]),
 io:format("file ~s was created~n",[HOME++"/.dip_aliases"]),
 file:close(F1).

