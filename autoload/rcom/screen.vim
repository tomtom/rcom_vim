" screen.vim
" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2012-07-10.
" @Last Change: 2012-07-15.
" @Revision:    223


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
let s:reuse = g:rcom#reuse

if g:rcom#screen#method == 'screen.vim'


    " type == 1: One-way communication
    let s:prototype = {'type': 1}


    if !exists(':ScreenShell')
        throw "Screen plugin (http://www.vim.org/scripts/script.php?script_id=2711) is not installed."
    endif


    function! s:prototype.Connect(reuse) dict "{{{3
        if s:connected == 0
            let s:reuse = a:reuse
            call screen#ScreenShell(s:RTerm(), 'horizontal')
        endif
        let s:connected += 1
        return s:connected
    endf


    function! s:prototype.Disconnect() dict "{{{3
        let s:connected -= 1
        if s:connected == 0
            if exists(':ScreenQuit')
                ScreenQuit
                " else
                "     echom "RCom/Screen: ScreenQuit is undefined. No active session?"
            endif
        endif
        return !s:connected
    endf


    function! s:prototype.Evaluate(rcode, mode) dict "{{{3
        " TLogVAR a:rcode, a:mode
        let rcode = s:RCode(a:rcode, a:mode)
        call self.Connect(s:reuse)
        " TLogVAR rcode
        call call(g:ScreenShellSend, [rcode])
        return ''
    endf


elseif g:rcom#screen#method == 'rcom'


    " type == 1: One-way communication
    let s:prototype = {'type': 2}


    if !exists('g:rcom#screen#rcom_cmd')
        " The name of the screen executable.
        " If the variable is user-defined, trust its value.
        let g:rcom#screen#rcom_cmd = executable('screen') ? 'screen' : ''  "{{{2
    endif
        
    if empty(g:rcom#screen#rcom_cmd)
        throw "rcom/screen: screen is not executable (see g:rcom#screen#rcom_cmd):" g:rcom#screen#rcom_cmd
    endif


    if !exists('g:rcom#screen#rcom_args')
        let g:rcom#screen#rcom_args = '-S vimrcom'   "{{{2
    endif


    if !exists('g:rcom#screen#rcom_shell')
        " The shell and terminal used to run |g:rcom#screen#rcom_cmd|.
        " If GUI is running, also start a terminal.
        " Default values with GUI running:
        "     Windows :: mintty
        "     Linux :: gnome-terminal
        let g:rcom#screen#rcom_shell =  ''   "{{{2
        if has('gui')
            if (has('win32') || has('win64'))
                let g:rcom#screen#rcom_shell = ' start "" mintty'
            elseif executable('gnome-terminal')
                let g:rcom#screen#rcom_shell = 'gnome-terminal -x'
            endif
        endif
    endif


    if !exists('g:rcom#screen#rcom_wait')
        " How long to wait after starting the terminal.
        let g:rcom#screen#rcom_wait = '500m'   "{{{2
    endif


    if !exists('g:rcom#screen#rcom_clear')
        " If true, always clear the screen before evaluating some R code.
        let g:rcom#screen#rcom_clear = 0   "{{{2
    endif


    if !exists('g:rcom#screen#rcom_sep')
        " Number of empty lines to separate commands.
        let g:rcom#screen#rcom_sep = 5   "{{{2
    endif


    if !exists('g:rcom#screen#rcom_timeout')
        " Timeout when waiting for an R command to finish to retrieve 
        " its output.
        let g:rcom#screen#rcom_timeout = 5   "{{{2
    endif


    let s:tempfile = ''


    function! s:prototype.Connect(reuse) dict "{{{3
        if s:connected == 0
            let s:reuse = a:reuse
            let args = [g:rcom#screen#rcom_shell,
                        \ g:rcom#screen#rcom_cmd, g:rcom#screen#rcom_args, '-t rcom'
                        \ ]
            if s:reuse
                call add(args, '-d -R')
            endif
            let cmd = join(args)
            " TLogVAR cmd
            exec 'silent! !' cmd '&'
            exec 'sleep' g:rcom#screen#rcom_wait
            call self.Evaluate(s:RTerm(), '')
        endif
        let s:connected += 1
        return s:connected
    endf


    function! s:prototype.Disconnect() dict "{{{3
        let s:connected -= 1
        if s:connected == 0
            call s:Screen('-X kill')
            if !s:reuse
                call s:Screen('-wipe vimrcom')
            endif
            if !empty(s:tempfile) && filereadable(s:tempfile)
                call delete(s:tempfile)
            endif
        elseif s:connected < 0
            let s:connected = 0
        endif
        return !s:connected
    endf


    function! s:prototype.Evaluate(rcode, mode) dict "{{{3
        let rv = ''
        let rcode = repeat([''], g:rcom#screen#rcom_sep) + s:RCode(a:rcode, a:mode)
        let s:tempfile = substitute(tempname(), '\\', '/', 'g')
        if a:mode == 'r'
            call add(rcode,
                        \ printf('writeLines(as.character(.Last.value), con = "%s")',
                        \     escape(s:tempfile, '"\'))
                        \ )
        endif
        " TLogVAR rcode
        call writefile(rcode, s:tempfile)
        let ftime = getftime(s:tempfile)
        let cmd = ' -p rcom -d -r -X eval '
                    \ . (g:rcom#screen#rcom_clear ? ' "clear" ' : '')
                    \ . printf(' "readbuf ''%s''" ', s:tempfile)
                    \ . ' "at rcom paste ."'
        " TLogVAR cmd
        call s:Screen(cmd)
        if a:mode == 'r'
            for i in range(g:rcom#screen#rcom_timeout * 5)
                sleep 200m
                if filereadable(s:tempfile) && ftime != getftime(s:tempfile)
                    let rv = join(readfile(s:tempfile), "\n")
                    break
                endif
            endfor
        endif
        return rv
    endf


    function! s:Screen(cmd) "{{{3
        let cmd = join([g:rcom#screen#rcom_cmd, g:rcom#screen#rcom_args, a:cmd])
        " TLogVAR cmd
        let rv = system(cmd)
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
    call add(args, g:rcom#screen#rterm_args)
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
    return rcode
endf


function! rcom#screen#Initialize(...) "{{{3
    " TLogVAR a:000
    return copy(s:prototype)
endf

