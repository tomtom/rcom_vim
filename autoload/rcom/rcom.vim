" rcom.vim
" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2012-06-20.
" @Last Change: 2012-07-11.
" @Revision:    0.0.31


let s:init = 0
       
if !s:init

    let s:prototype = rcom#base#Initialize()


    ruby <<CODE
    require 'win32ole'
    # require 'tmpdir'
        
    class RCom < RComBase

        def initialize_server
            @features['history'] = true
            @r_server = WIN32OLE.new("StatConnectorSrv.StatConnector")
            @r_server.Init("R")
            @r_printer = WIN32OLE.new("StatConnTools.StringLogDevice")
            @r_printer.BindToServerOutput(@r_server)
        end

        def reuse_server
            @features['history'] = true
            begin
                @r_server = WIN32OLE.new("RCOMServerLib.StatConnector")
            rescue Exception => e
                throw "Error when connecting to R. Make sure it is already running. #{e}"
            end
            @r_server.Init("R")
            @r_printer = nil
        end

        def r_send(text)
            @r_server.EvaluateNoReturn(text)
        end

        def r_sendw(text)
            @r_server.Evaluate(text)
        end

        def r_quit(text)
            @r_server.Close
        end

        def r_print(out)
            out << @r_printer.Text
        end
   
        def r_set_output(text)
            @r_printer.Text = text
        end

    end
CODE


    function! rcom#rcom#Initialize(...) "{{{3
        " TLogVAR a:000
        return copy(s:prototype)
    endf


    let s:init = 1
endif

