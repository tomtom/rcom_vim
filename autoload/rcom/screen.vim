" screen.vim
" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2012-07-10.
" @Last Change: 2013-07-18.
" @Revision:    566


if !exists('g:rcom#screen#method')
    " How rcom should use screen to connect to R (see 
    " |g:rcom#screen#rterm|). If rcom's default method doesn't work for 
    " you, you might want to change the value of this variable.
    "
    " If screen's terminal is messed up (e.g. after an error), you might 
    " want to trigger a "clear" command (in screen: <c-a>:clear<cr>) 
    " before continuing.
    "
    " Supported Values:
    "     screen.vim ... Use Eric Van Dewoestine's screen plugin, which 
    "         also supports tmux; (see 
    "         http://www.vim.org/scripts/script.php?script_id=2711)
    "     rcom ... This plugin's own simplified approach (also supports 
    "         omni-completion |compl-omni|)
    let g:rcom#screen#method = 'rcom'   "{{{2
endif

if !exists('g:rcom#screen#mode')
    " Determine how to paste code. Possible values:
    "
    "   1 ... Paste the code
    "   2 ... Save the code to a file and source that file
    " 
    " This variable should only be changed if |g:rcom#screen#method| is 
    " rcom.
    let g:rcom#screen#mode = 1   "{{{2
endif


if !exists('g:rcom#screen#rterm')
    let g:rcom#screen#rterm = executable('Rterm') ? 'Rterm --ess' : 'R'   "{{{2
endif


if !exists('g:rcom#screen#rterm_args')
    " Command-line arguments passed to Rterm (see |g:rcom#screen#rterm|).
    let g:rcom#screen#rterm_args = ''   "{{{2
endif


if !exists('g:rcom#screen#save')
    " Values:
    "     0 ... Don't save the image
    "     1 ... Save an image only if a file .Rdata exists
    "     2 ... Always save an image
    let g:rcom#screen#save = 1   "{{{2
endif


if !exists('g:rcom#screen#encoding')
    " If non-empty, use |iconv()| to recode input.
    let g:rcom#screen#encoding = ''   "{{{2
endif


let s:connected = 0
let s:reuse = g:rcom#reuse || !has("gui_running")


function! rcom#screen#RcomOptions() "{{{3
    let options = {'features': []}
    if s:reuse
        call add(options.features, 'reuse')
    else
        call add(options.features, 'history')
    endif
    return options
endf


if g:rcom#screen#method == 'screen.vim'


    if !exists(':ScreenShell')
        throw "Screen plugin (http://www.vim.org/scripts/script.php?script_id=2711) is not installed."
    endif


    " type == 1: One-way communication
    let s:prototype = {'type': 1}
    let s:prototype.Options = function('rcom#screen#RcomOptions')


    function! s:prototype.Connect(reuse) dict "{{{3
        " TLogVAR a:reuse
        if s:connected == 0
            let s:reuse = a:reuse
            call screen#ScreenShell(s:RTerm(), 'horizontal')
        endif
        let s:connected += 1
        return s:connected
    endf


    function! s:prototype.Disconnect() dict "{{{3
        let s:connected -= 1
        let rv = 0
        if s:connected == 0
            call self.Evaluate('rcom.quit()', '')
            if exists(':ScreenQuit')
                ScreenQuit
                let rv = 1
            endif
        endif
        return rv
    endf


    function! s:prototype.Evaluate(rcode, mode) dict "{{{3
        " TLogVAR a:rcode, a:mode
        let rcode = s:RCode(a:rcode, a:mode)
        call self.Connect(s:reuse)
        " TLogVAR rcode
        call call(g:ScreenShellSend, [rcode])
        return ''
    endf

    function! s:prototype.Filename(filename) dict "{{{3
        return a:filename
    endf


elseif g:rcom#screen#method == 'rcom'


    " type == 1: One-way communication
    let s:prototype = {'type': 2}
    let s:prototype.Options = function('rcom#screen#RcomOptions')


    if !exists('g:rcom#screen#rcom_cmd')
        " The name of the screen executable.
        " If the variable is user-defined, trust its value.
        let g:rcom#screen#rcom_cmd = executable('screen') ? 'screen' : ''  "{{{2
    endif
        
    if empty(g:rcom#screen#rcom_cmd)
        throw "rcom/screen: screen is not executable (see g:rcom#screen#rcom_cmd):" g:rcom#screen#rcom_cmd
    endif


    if !exists('g:rcom#screen#rcom_session')
        let g:rcom#screen#rcom_session = 'vimrcom_'. v:servername   "{{{2
    endif


    if !exists('g:rcom#screen#rcom_shell')
        " The shell and terminal used to run |g:rcom#screen#rcom_cmd|.
        " If GUI is running, also start a terminal.
        "
        " Default values with GUI running:
        "     Windows :: mintty
        "     Linux :: gnome-terminal
        let g:rcom#screen#rcom_shell =  ''   "{{{2
        if has('gui_running')
            if (has('win32') || has('win64'))
                let g:rcom#screen#rcom_shell = ' start "" mintty %s'
            elseif executable('gnome-terminal')
                let g:rcom#screen#rcom_shell = 'gnome-terminal -x %s &'
            endif
        endif
    endif


    if !exists('g:rcom#screen#rcom_init_wait')
        " How long to wait after starting the terminal.
        let g:rcom#screen#rcom_init_wait = 1   "{{{2
    endif


    if !exists('g:rcom#screen#rcom_wait')
        " How long to wait after executing a command.
        let g:rcom#screen#rcom_wait = '500m'   "{{{2
    endif


    if !exists('g:rcom#screen#rcom_clear')
        " If true, always clear the screen before evaluating some R code.
        let g:rcom#screen#rcom_clear = 0   "{{{2
    endif


    if !exists('g:rcom#screen#rcom_sep')
        " Number of empty lines to separate commands.
        let g:rcom#screen#rcom_sep = 0   "{{{2
    endif

    
    if !exists('g:rcom#screen#rcom_send_after')
        " A key sequence sent to the terminal via screen's stuff command 
        " after evaluating R code.
        let g:rcom#screen#rcom_send_after = '\15\15'   "{{{2
    endif


    if !exists('g:rcom#screen#rcom_timeout')
        " Timeout when waiting for an R command to finish to retrieve 
        " its output.
        let g:rcom#screen#rcom_timeout = 5   "{{{2
    endif


    if !exists('g:rcom#screen#convert_path')
        " If non-empty, use this command to convert paths that are 
        " passed on to R.
        let g:rcom#screen#convert_path = (has('win32unix') && g:rcom#screen#rterm =~# 'Rterm') ? 'cygpath -m %s' : ''  "{{{2
    endif


    if !exists('g:rcom#screen#rcom_maxsize')
        let g:rcom#screen#rcom_maxsize = 2048   "{{{2
    endif


    let s:tempfile = ''


    function! s:prototype.Connect(reuse, ...) dict "{{{3
        let start_rterm = a:0 >= 1 ? a:1 : 1
        " TLogVAR a:reuse, start_rterm
        let s:connected += 1
        " echom "DBG Connect s:connected =" s:connected
        if s:connected == 1
            let s:reuse = a:reuse
            call s:ScreenConnect()
            if start_rterm
                call self.Evaluate(s:RTerm(), 'x')
            endif
            let rv = 1
        else
            let rv = 0
        endif
        return rv
    endf


    function! s:prototype.Disconnect() dict "{{{3
        " echom "DBG Disconnect s:connected =" s:connected
        let rv = 0
        try
            if s:connected == 1
                call self.Evaluate('rcom.quit()', '')
                call s:Screen('-X eval "msgwait 5" "msgminwait 1"')
                call s:Screen('-X kill')
                let rv = 1
                if !s:reuse
                    call s:Screen('-wipe '. g:rcom#screen#rcom_session)
                endif
                if !empty(s:tempfile) && filereadable(s:tempfile)
                    call delete(s:tempfile)
                endif
                if exists(s:paste_file) && filereadable(s:paste_file)
                    call delete(s:paste_file)
                endif
            endif
        finally
            let s:connected -= 1
            if s:connected < 0
                let s:connected = 0
            endif
        endtry
        return rv
    endf


    " rcode ... a list of lines of r code
    " mode  ... r ... read the result
    "           x ... evaluate as is (ignore |g:rcom#screen#mode|)
    function! s:prototype.Evaluate(rcode, mode) dict "{{{3
        " TLogVAR a:rcode, a:mode
        call s:ScreenEnsureAttached(self)
        let rcode = repeat([''], g:rcom#screen#rcom_sep) + s:RCode(a:rcode, a:mode)
        if empty(s:tempfile)
            let s:tempfile = substitute(tempname(), '\\', '/', 'g')
        endif
        if a:mode == 'r'
            call add(rcode,
                        \ printf('writeLines(as.character(.Last.value), con = "%s")',
                        \     escape(self.Filename(s:tempfile), '"\'))
                        \ )
        endif
        " TLogVAR rcode
        let cmd0 = '-X eval '
                    \ . ' "msgminwait 0"'
                    \ . ' "msgwait 0"'
                    \ . (g:rcom#screen#rcom_clear ? ' "at rcom clear"' : '')
                    \ . printf(' "bufferfile ''%s''"', s:tempfile)
                    \ . ' readbuf'
                    \ . ' "at rcom paste ."'
                    " \ . ' "at rcom redisplay"'
        " TLogVAR cmd0

        if g:rcom#screen#mode == 1 || a:mode == "x"

            let parts = []
            let part = []
            let part_size = 0
            for line in rcode
                let llen = strlen(line)
                if part_size + llen > g:rcom#screen#rcom_maxsize
                    call add(parts, part)
                    let part = []
                    let part_size = 0
                endif
                call add(part, line)
                let part_size += llen
            endfor
            call add(parts, part)

        elseif g:rcom#screen#mode == 2

            if !exists('s:paste_file')
                let s:paste_file = substitute(tempname(), '\\', '/', 'g')
            endif
            call writefile(rcode, s:paste_file)
            let rcode0 = [printf('tryCatch(source("%s"), error = print)',
                        \     escape(self.Filename(s:paste_file), '"\'))]
            " TLogVAR rcode0
            let rcode = repeat([''], g:rcom#screen#rcom_sep) + s:RCode(rcode0, a:mode)
            " TLogVAR rcode
            let parts = [rcode]

        else
            throw 'rcom/screen: g:rcom#screen#mode must be 1 or 2 but was '. g:rcom#screen#mode
        endif
        " TLogVAR parts

        " echohl Special
        " echo "RCOM/screen: Sending rcode ... Please wait"
        " echohl NONE
        let result = []
        for part in parts
            " TLogVAR part
            call writefile(part, s:tempfile)
            let ftime = getftime(s:tempfile)
            let fsize = getfsize(s:tempfile)
            if a:mode == 'r'
                let cmd = cmd0
            else
                let cmd = cmd0 . printf(' "register a rcom%s"', fsize == 4 ? '_' : '')
                            \ . ' "paste a ."'
                            \ . ' writebuf'
            endif
            " TLogVAR cmd
            call s:Screen(cmd)
            for i in range(g:rcom#screen#rcom_timeout * 5)
                sleep 200m
                " echom "DBG Evaluate" filereadable(s:tempfile) ftime getftime(s:tempfile) fsize getfsize(s:tempfile)
                " echom "DBG Evaluate" string(rcode) string(readfile(s:tempfile))
                if fsize != getfsize(s:tempfile) || ftime != getftime(s:tempfile)
                            \ || (a:mode == 'r' && i % 5 == 0 && readfile(s:tempfile) != rcode)
                    if a:mode == 'r'
                        let result += readfile(s:tempfile)
                        " TLogVAR 1, len(result)
                        break
                    else
                        break
                    endif
                endif
            endfor
        endfor
        if !empty(g:rcom#screen#rcom_send_after)
            " TLogVAR g:rcom#screen#rcom_send_after
            call s:Screen('-X "stuff '. escape(g:rcom#screen#rcom_send_after, '"') .'"')
        endif
        " redraw
        " echo
        " TLogVAR result
        return join(result, "\n")
    endf


    function! s:prototype.Filename(filename) dict "{{{3
        if empty(g:rcom#screen#convert_path)
            return a:filename
        else
            let cmd = printf(g:rcom#screen#convert_path, shellescape(a:filename))
            let filename = system(cmd)
            " TLogVAR cmd, filename
            return filename
        endif
    endf


    function! s:ScreenCmd(initial, args) "{{{3
        " TLogVAR a:initial, a:args
        let eval = '-X eval'
        let shell = 0
        if a:initial
            if has("gui_running") || !empty(g:rcom#screen#rcom_shell)
                let shell = 1
                let cmd = [
                            \ g:rcom#screen#rcom_cmd,
                            \ s:ScreenSession(),
                            \ '-t rcom'
                            \ ]
                if !s:reuse
                    call add(cmd, '-d -R')
                endif
                " call add(cmd, '-X partial on')
            elseif $TERM =~ '^screen'
                let cmd = [g:rcom#screen#rcom_cmd,
                            \ s:ScreenSession(),
                            \ eval,
                            \ '"title vim"',
                            \ '"screen -t rcom" "at rcom split" focus "select rcom"',
                            \ 'focus "select vim"'
                            \ ]
            else
                throw 'RCom/screen: You have to run vim within screen or set g:rcom#screen#rcom_shell'
            endif
        else
            let cmd = [
                        \ g:rcom#screen#rcom_cmd,
                        \ s:ScreenSession(),
                        \ ]
        endif
        if !empty(a:args)
            let eval_arg = a:args =~ '\V\^'. eval .'\>'
            " TLogVAR eval_arg, eval, a:args
            if a:args[0:0] == '-'
                call add(cmd, a:args)
            else
                call add(cmd, eval)
                call add(cmd, '"at rcom '. escape(a:args, '''"\') .'"')
            endif
        endif
        let cmdline = join(cmd)
        if shell
            let cmdline = printf(g:rcom#screen#rcom_shell, cmdline)
        endif
        " TLogVAR cmdline
        return cmdline
    endf


    function! s:ScreenSession() "{{{3
        return has('gui_running') ? ('-D -R -S '. g:rcom#screen#rcom_session) : ''
    endf


    function! s:ScreenEnsureAttached(dict) "{{{3
        " echom "DBG ScreenEnsureAttached s:connected =" s:connected
        if s:connected == 0
            call a:dict.Connect(s:reuse)
        elseif has('gui_running')
            let sessions = split(system('screen -list'), '\n')
            let attached = filter(copy(sessions), 'v:val =~ ''^\s*\d\+\.'. g:rcom#screen#rcom_session .'\s\+(Attached)''')
            if empty(attached)
                " TLogVAR attached
                let detached = filter(copy(sessions), 'v:val =~ ''^\s*\d\+\.'. g:rcom#screen#rcom_session .'\s\+(Detached)''')
                call s:ScreenConnect()
            endif
        endif
    endf


    function! s:ScreenConnect() "{{{3
        let cmd = s:ScreenCmd(1, '')
        " TLogVAR cmd
        if !empty(cmd)
            exec 'silent! !'. cmd
            if has("gui_running")
                if !empty(g:rcom#screen#rcom_shell)
                    exec 'sleep' g:rcom#screen#rcom_init_wait
                endif
            else
                redraw!
            endif
        endif
        call s:Screen('-wipe')
    endf


    function! s:Screen(cmd) "{{{3
        " TLogVAR a:cmd
        let cmd = s:ScreenCmd(0, a:cmd)
        " TLogVAR cmd
        if has("win32unix")
            exec 'silent! !'. cmd
            let rv = ''
        else
            let rv = system(cmd)
        endif
        " exec 'sleep' g:rcom#screen#rcom_wait
        " TLogVAR rv
        return rv
    endf


else


    throw "rcom/screen: Unsupported method (see g:rcom#screen#method):" g:rcom#screen#method


endif


function! s:RTerm() "{{{3
    let args = [g:rcom#screen#rterm]
    let save = 0
    if g:rcom#screen#save == 2
        let save = 1
    elseif g:rcom#screen#save == 1
        let save = filereadable('.Rdata')
    endif
    call add(args, save ? '--save' : '--no-save')
    if !empty(g:rcom#screen#rterm_args)
        call add(args, g:rcom#screen#rterm_args)
    endif
    return join(args)
endf


function! s:RCode(rcode, mode) "{{{3
    if type(a:rcode) == 3
        let rcode = a:rcode
    else
        let rcode = split(a:rcode, '\n')
    endif
    if has('+iconv') && !empty(g:rcom#screen#encoding) && &l:encoding != g:rcom#screen#encoding
        try
            call map(rcode, 
                        \ printf('iconv(v:val, %s, %s)',
                        \     string(&l:encoding),
                        \     string(g:rcom#screen#encoding)))
        catch
            echoerr "RCom: Error when encoding R code: Check the value of g:rcom#screen#encoding:" v:errormsg
        endtry
    endif
    if a:mode == 'p'
        call add(rcode, 'print(.Last.value)')
    endif
    " TLogVAR rcode
    return rcode
endf


function! rcom#screen#Initialize(...) "{{{3
    " TLogVAR a:000
    return copy(s:prototype)
endf

