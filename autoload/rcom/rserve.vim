" rcom.vim
" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2012-06-20.
" @Last Change: 2012-07-11.
" @Revision:    0.0.161

let s:init = 0

if !s:init

    if !exists('g:rcom#rserve#args')
        " The arguments passed to rserve-client's Connection class.
        " Useful fields are:
        "   port_number
        "   cmd_init
        " See http://ruby-statsample.rubyforge.org/rserve-client/Rserve/Connection.html#method-c-new 
        " for details.
        let g:rcom#rserve#args = {'port_number': 6311}   "{{{2
    endif


    if !exists('g:rcom#rserve#default_external_encoding')
        let g:rcom#rserve#default_external_encoding = "utf-8"   "{{{2
    endif


    if !exists('g:rcom#rserve#home')
        " If not empty, don't rely on rubygems to find rserve-client but add 
        " its directory to $LOAD_PATH.
        let g:rcom#rserve#home = ""   "{{{2
    endif


    if !exists('g:rcom#rserve#support_sessions')
        " If true, the rserver supports sessions.
        " At the time of writing, rserver does not support sessions on 
        " MS Windows.
        let g:rcom#rserve#support_sessions = !(has('win16') || has('win32') || has('win64'))   "{{{2
    endif


    if !g:rcom#rserve#support_sessions && serverlist() =~ '\<RCOM\>' && v:servername != 'RCOM'
        throw "RCOM#RServe: Rserve doesn't support sessions on this platform. Cannot connect to rserve. See :help g:rcom#rserve#support_sessions"
    end

    if !empty(g:rcom#rserve#home)
        exec 'ruby $LOAD_PATH.unshift' string(fnameescape(g:rcom#rserve#home))
    endif

    let s:prototype = rcom#base#Initialize()


    ruby <<CODE
    require 'rserve'
        
    class RCom < RComBase
        def initialize_server
            @args = {}
            for k, v in VIM::evaluate('g:rcom#rserve#args')
                @args[k.to_sym] = v
            end
            # debug("initialize_server @args=#{@args}")
            @r_server = nil
            @r_session = nil
            @support_sessions = VIM::evaluate('g:rcom#rserve#support_sessions').to_i != 0
            @r_printer = []
        end

        def reuse_server
            initialize_server
        end

        def attach
            if @support_sessions
                # debug "attach @r_session=#{@r_session}"
                if @r_session.nil?
                    @r_server = Rserve::Connection.new(@args)
                else
                    @r_server = @r_session.attach
                end
            elsif @r_server.nil?
                @r_server = Rserve::Connection.new(@args)
            end
            # debug "attach @r_server=#{@r_server}"
        end

        def detach
            if @support_sessions
                @r_session = @r_server.detach
                # debug "detach @r_session=#{@r_session}"
            end
        end

        def r_send(text)
            rserve_send {@r_server.eval(text).to_ruby}
        end

        def r_sendw(text)
            rserve_send {@r_server.eval(text).to_ruby}
        end

        def r_quit()
            if @support_sessions
                @r_server = @r_session.attach
            end
            @r_server.shutdown unless @r_server.nil?
        end

        def r_print(out)
            # VIM::command("echom 'DBG r_print' #{@r_printer.inspect.inspect}")
            case @r_printer
            when String
                out << @r_printer
            when Array
                out << @r_printer.join("\n")
            when nil
            else
                out << @r_printer.to_s
            end
            # VIM::command("echom 'DBG r_print' #{out.inspect.inspect}")
        end
   
        def r_set_output(text)
            @r_printer = []
        end

        def rserve_send
            # debug "rserve_send 1"
            attach
            # debug "rserve_send 2"
            begin
                # @r_session = @r_server.void_eval_detach(wrap_expr(text))
                @r_server.void_eval('rcom.connection <- textConnection("rcom.sink", "w")')
                @r_server.void_eval('sink(rcom.connection)')
                # debug "rserve_send 3"
                rv = yield
                # debug "rserve_send 4"
                @r_server.void_eval('sink()')
                @r_server.void_eval('close(rcom.connection)')
                @r_printer = @r_server.eval('rcom.sink').to_ruby
                @r_server.void_eval('rcom.connection <- NULL')
                @r_server.void_eval('unlockBinding("rcom.sink", .GlobalEnv)')
                @r_server.void_eval('rcom.sink <- NULL')
                # debug "rserve_send 5"
            ensure
                # debug "rserve_send 6"
                detach
                # debug "rserve_send 7"
            end
            # VIM::command("echom 'DBG rserve_send rv' '#{rv.inspect}'")
            # VIM::command("echom 'DBG rserve_send printer' '#{@r_printer.inspect}'")
            rv
        end

    end
CODE


    function! rcom#rserve#Initialize(...) "{{{3
        " TLogVAR a:000
        return copy(s:prototype)
    endf


    let s:init = 1
endif

