" base.vim
" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2012-06-21.
" @Last Change: 2012-07-20.
" @Revision:    0.0.112


let s:init = 0

if !s:init

    ruby <<CODE
    class RComBase
        @@interpreter = nil
        @@connections = 0

        class << self
            def interpreter
                @@interpreter
            end

            def connect(reuse)
                if @@interpreter.nil?
                    @@interpreter = RCom.new(reuse)
                    rv = 1
                else
                    rv = 0
                end
                @@connections += 1
                return rv
            end

            def disconnect
                if @@connections > 0
                    @@connections -= 1
                end
                rv = 0
                unless @@interpreter.nil?
                    if @@connections == 0
                        @@interpreter.quit
                        rv = 1
                    end
                end
                return rv
            end
        end

        def initialize(reuse)
            @reuse = reuse
            # debug "initialize reuse=#{reuse}"
            @features = {}
            case @reuse
            when 0
                initialize_server
            when 1
                reuse_server
            else
                throw "Unsupported R reuse mode: #{@reuse}"
            end
        end

        def rcom_features
            features = []
            features << 'history' if @features['history']
            features << 'reuse' if @reuse
            return features
        end

        def initialize_server
            throw "Abstract method"
        end

        def reuse_server
            throw "Abstract method"
        end

        def r_send(text)
            throw "Abstract method"
        end

        def r_sendw(text)
            throw "Abstract method"
        end
   
        def r_quit()
            throw "Abstract method"
        end

        def r_get_output()
            throw "Abstract method"
        end
   
        def r_set_output(text)
            throw "Abstract method"
        end
   
        def escape_help(text)
            text =~ /^".*?"$/ ? text : text.inspect
        end

        def evaluate(text, mode=0)
            out = ""
            text = text.sub(/^\s*\?([^\?].*)/) {"help(#{escape_help($1)})"}
            text = text.sub(/^\(/) {"print("}
            text = text.sub(/^\s*(help\(.*?\))/) {"print(#$1)"}
            if text =~ /^\s*(print\()?help(\.\w+)?\b/m
                return if VIM::evaluate("g:rcom#help") == "0"
                meth = :r_send
                if VIM::evaluate("g:rcom#help") == "2"
                    text.sub!(/^\s*(print\()?help(\.\w+)?\s*\(/m, 'RSiteSearch(')
                end
            else
                meth = :r_sendw
                if mode == "p" and text =~ /^\s*(print|str|cat)\s*\(/
                    mode = ""
                end
                text = %{eval(parse(text=#{text.inspect}))}
                # VIM.command(%{call inputdialog('text = #{text}')})
            end
            case mode
                when 'r'
                meth = :r_sendw
            else
                if @reuse != 0
                    meth = :r_send
                end
            end
            # VIM.command(%{call inputdialog('mode = #{mode}; text = #{text}; meth = #{meth}; reuse = #@reuse')})
            # log("DBG interpreter.evaluate meth=#{meth.inspect}")
            rv = nil
            begin
                if mode == 'p'
                    # rv = send(meth, %{do.call(cat, c(as.list(parse(text=#{text.inspect})), sep="\n"))})
                    rv = send(meth, %{print(#{text})})
                else
                    rv = send(meth, text)
                end
            rescue Exception => e
                if e.to_s =~ /unknown property or method `EvaluateNoReturn'/
                    return 'It seems R GUI was closed.'
                else
                    log(e.to_s)
                end
            end
            # VIM.command(%{echom "DBG interpreter.evaluate rv=" #{rv.inspect.inspect}})
            r_print(out)
            # VIM.command(%{echom "DBG interpreter.evaluate 1 out=" #{out.inspect.inspect}})
            # if out.empty?
            # else
            #     out.gsub!(/\r\n/, "\n")
            #     out.sub!(/^\s+/, "")
            #     out.sub!(/\s+$/, "")
            #     out.gsub!(/^(\[\d+\])\n /m, "\\1 ")
            #     r_set_output("")
            # end
            case mode
            when "p"
                # out << "\n# => #{rv.to_s}"
                out << "\n#{rv.to_s}"
            end
            # VIM.command(%{echom "DBG interpreter.evaluate 2 out=" #{out.inspect.inspect}})
            log(out) unless out.empty?
            # log("DBG interpreter.evaluate rv=#{rv.inspect}")
            # case meth
            # when :r_sendw
                return rv
            # else
            #     return nil
            # end
        end

        def log(text)
            # VIM.command(%{echom #{text.inspect.inspect}})
            VIM.command(%{call rcom#Log(#{text.inspect})})
        end

        def debug(text)
            VIM::command(%{echom "DBG" #{text.inspect.inspect}})
        end

        def quit(just_the_server = false)
            unless just_the_server
                begin
                    r_send(%{rcom.quit()})
                rescue
                end
            end
            begin
                r_quit
            rescue
            end
            return true
        end
    end
CODE


    " type == 2: Support two-way communication
    let s:prototype = {'type': 2}

    function! s:prototype.Connect(reuse) dict "{{{3
        ruby VIM::command(%{let rv = #{RCom.connect(VIM::evaluate('a:reuse'))}})
        return rv
    endf

    function! s:prototype.Disconnect() dict "{{{3
        ruby VIM::command(%{let rv = #{RCom.disconnect}})
        return rv
    endf

    function! s:prototype.Options() dict "{{{3
        let options = {'features': []}
        ruby VIM::command(%{let options.features = #{RCom.interpreter.rcom_features}})
        return options
    endf

    function! s:prototype.Evaluate(rcode, mode) dict "{{{3
        " TLogVAR a:rcode, a:mode
        let value = ''
        " silent ruby <<CODE
        ruby <<CODE
            # VIM.command(%{echom 'DBG Evaluate' #{RCom.interpreter.class.inspect.inspect}})
            rcode = VIM.evaluate('a:rcode')
            mode = VIM.evaluate('a:mode')
            value = RCom.interpreter.evaluate(rcode, mode)
            VIM.command(%{let value=#{(value || '').inspect}})
CODE
        return value
    endf

    function! s:prototype.Filename(filename) dict "{{{3
        return a:filename
    endf


    function! rcom#base#Initialize(...) "{{{3
        " TLogVAR a:000
        return copy(s:prototype)
    endf


    let s:init = 1
endif

