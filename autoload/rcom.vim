" rcom.vim -- Execute R code via rcom. rserve, or screen
" @Author:      Thomas Link (mailto:micathom AT gmail com?subject=[vim])
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2010-02-23.
" @Last Change: 2012-07-20.
" @Revision:    737
" GetLatestVimScripts: 2991 1 :AutoInstall: rcom.vim

let s:save_cpo = &cpo
set cpo&vim

if !exists('loaded_rcom')
    let loaded_rcom = 3
endif


function! s:IsRemoteServer() "{{{3
    return has('clientserver') && v:servername == 'RCOM'
endf


if !exists('g:rcom#method')
    " The following methods to connect to R are supported:
    "     screen ... Use Gnu Screen or tmux (see |g:rcom#screen#method|)
    "     rserve ... Use rserve
    "              (requires vim's |ruby| interface and the 
    "              rserve-client ruby gem to be installed)
    "     rcom ... Use rcom from http://rcom.univie.ac.at/
    "              (requires vim's |ruby| interface; as of plugin 
    "              version 0.3 the rcom method is untested)
    let g:rcom#method = 'screen'   "{{{2
endif
if index(['rcom', 'rserve', 'screen'], g:rcom#method) == -1
    echoerr "RCom: g:rcom#method must be one of: rcom, rserve, screen'
endif


if !exists('g:rcom#help')
    " Handling of help commands.
    "
    "   0 ... disallow
    "   1 ... allow
    "   2 ... Use RSiteSearch() instead of help() (this option requires 
    "         Internet access)
    let g:rcom#help = 1   "{{{2
endif


if !exists('g:rcom#reuse')
    " How to interact with R.
    "    0 ... Start a headless instance of R and transcribe the 
    "          interaction in VIM
    "    1 ... Re-use a running instance of R GUI (default)
    let g:rcom#reuse = g:rcom#method == 'rcom'   "{{{2
endif


if !exists('g:rcom#options')
    " Inital set of commands to send to R.
    let g:rcom#options = 'warn = 1'.(has('gui_running') ? ', help_type = "html"' : '')  "{{{2
endif


if !exists('g:rcom#options_reuse_0')
    " Inital set of R options to send to R if |g:rcom#reuse| is 0.
    let g:rcom#options_reuse_0 = ''   "{{{2
endif


if !exists('g:rcom#options_reuse_1')
    " Inital set of R options to send to R if |g:rcom#reuse| is 1.
    let g:rcom#options_reuse_1 = ''   "{{{2
endif


if !exists('g:rcom#r_object_browser')
    " Default object browser.
    let g:rcom#r_object_browser = 'str'   "{{{2
endif


if !exists('g:rcom#transcript_cmd')
    " Command used to display the transcript buffers.
    let g:rcom#transcript_cmd = s:IsRemoteServer() ? 'edit' : 'vert split'   "{{{2
endif


if !exists('g:rcom#log_cmd')
    " Command used to display the transcript buffers.
    let g:rcom#log_cmd = 'split'   "{{{2
endif


if !exists('g:rcom#log_trim')
    " If true, remove printed items from the log.
    let g:rcom#log_trim = 1   "{{{2
endif


if !exists('g:rcom#server')
    " If non-empty, use this ex command to start an instance of GVIM 
    " that acts as a server for remotely evaluating R code. The string 
    " will be evaluated via |:execute|.
    " The string may contain %s where rcom-specific options should be 
    " included.
    "
    " Example: >
    "   let g:rcom#server = 'silent ! start "" gvim.exe "+set lines=18" "+winpos 1 700" %s'
    "   let g:rcom#server = 'silent ! gvim %s &'
    let g:rcom#server = ""   "{{{2
endif


if !exists('g:rcom#server_wait')
    " Seconds to wait after starting |rcom#server|.
    let g:rcom#server_wait = 10   "{{{2
endif


if !exists('g:rcom#highlight_debug')
    " Highlight group for debugged functions.
    let g:rcom#highlight_debug = 'SpellRare'   "{{{2
endif


if !exists('#RCom')
    augroup RCom
        autocmd!
    augroup END
endif


let s:rcom = {}
let s:log  = {}
let s:defs = {}


function! s:GetConnection(...) "{{{3
    let bufnr = a:0 >= 1 ? a:1 : bufnr('%')
    let r_connection = s:rcom[bufnr]
    return r_connection
endf


function! s:ShouldRemoteSend() "{{{3
    if has('clientserver') && v:servername != 'RCOM'
        if serverlist() =~ '\<RCOM\>'
            return 1
        elseif !empty(g:rcom#server)
            let cmd = g:rcom#server
            if cmd =~ '\(%\)\@<!%s\>'
                let cmd = printf(g:rcom#server, '--servername RCOM')
            endif
            exec cmd
            redraw
            echo "RCom: Waiting for GVIM to start"
            let i = 0
            while i < g:rcom#server_wait
                sleep 1
                if serverlist() =~ '\<RCOM\>'
                    redraw
                    echo
                    return 1
                endif
                let i += 1
            endwh
            echoerr "RCom: Got tired of waiting for GVim RCOM server"
            return 0
        else
            return 0
        endif
    else
        return 0
    endif
endf


function! s:LogN() "{{{3
    return len(keys(s:log))
endf


function! s:LogID() "{{{3
    return printf('%05d %s', s:LogN(), strftime('%Y-%m-%d %H:%M:%S'))
endf


function! rcom#Log(text) "{{{3
    if a:text !~ '^RCom: \d\+ messages in the log$'
        " TLogVAR a:text
        let s:log[s:LogID()] = a:text
        if bufwinnr('__RCom_Log__') != -1
            call rcom#LogBuffer()
        else
            call s:Warning('RCom: '. s:LogN() .' messages in the log')
        endif
    endif
endf


function! s:Warning(text) "{{{3
    echohl WarningMsg
    echom a:text
    echohl NONE
endf


" :display: rcom#Quit(?bufnr=bufnr('%'))
" Disconnect from the R GUI.
" Usually not called by the user.
function! rcom#Quit(...) "{{{3
    " TLogVAR a:000
    if a:0 >= 1
        let bufnr = a:1
    else
        let bufnr = expand('<abuf>')
        if empty(bufnr)
            let bufnr = bufnr('%')
        endif
    endif
    " TLogVAR bufnr, bufname(bufnr)
    if has_key(s:rcom, bufnr)
        try
            let r_connection = s:GetConnection(bufnr)
            " TLogVAR r_connection
            let closed = r_connection.Disconnect()
            " TLogVAR closed
            call remove(s:rcom, bufnr)
            exec printf('autocmd! RCom BufUnload <buffer=%s>', bufnr)
        catch
            call rcom#Log(v:exception)
        endtry
    else
        " echom "DBG ". string(keys(s:rcom))
        call rcom#Log("RCom: Not an R buffer. Call rcom#Initialize() first.")
    endif
endf


function! s:Escape2(text, chars) "{{{3
    return escape(escape(a:text, a:chars), '\')
endf


" Omnicompletion for R.
" See also 'omnifunc'.
function! rcom#Complete(findstart, base) "{{{3
    " TLogVAR a:findstart, a:base
    if a:findstart
        let line = getline('.')
        let start = col('.') - 1
        while start > 0 && line[start - 1] =~ '[._[:alnum:]]'
            let start -= 1
        endwhile
        return start
    else
        let r_connection = rcom#Initialize(g:rcom#reuse)
        " TLogVAR r_connection
        if r_connection.type == 2
            let rcode = printf('rcom.complete(%s, %s)',
                        \ string('^'. s:Escape2(a:base, '^$.*\[]~"')),
                        \ string(exists('w:tskeleton_hypercomplete') ? 'tskeleton' : ''))
            let completions = rcom#Evaluate([rcode], 'r')
            " TLogVAR completions
            let clist = split(completions, '\n')
            " TLogVAR clist
            return clist
        else
            return []
        endif
    endif
endf


" Display help on the word under the cursor.
function! rcom#Keyword(...) "{{{3
    let word = a:0 >= 1 && !empty(a:1) ? a:1 : expand("<cword>")
    " TLogVAR word
    if word =~ '^\(if\|else\|repeat\|while\|function\|for\|in\|next\|break\|[[:punct:]]\)$'
        let name = string(word)
        let namestring = '""'
    else
        let name = word
        let namestring = string(word)
    endif
    call rcom#EvaluateInBuffer(printf('rcom.keyword(%s, %s)', name, namestring), '')
endf


" Inspect the word under the cursor.
function! rcom#Info(...) "{{{3
    let word = a:0 >= 1 && !empty(a:1) ? a:1 : expand("<cword>")
    " TLogVAR word
    call rcom#EvaluateInBuffer(printf('rcom.info(%s)', string(word)), '')
endf


" :display: rcom#GetSelection(mode, ?mbeg="'<", ?mend="'>", ?opmode='selection')
" mode can be one of: selection, lines, block
function! rcom#GetSelection(mode, ...) range "{{{3
    if a:0 >= 2
        let mbeg = a:1
        let mend = a:2
    else
        let mbeg = "'<"
        let mend = "'>"
    endif
    let opmode = a:0 >= 3 ? a:3 : 'selection'
    let l0   = line(mbeg)
    let l1   = line(mend)
    let text = getline(l0, l1)
    let c0   = col(mbeg)
    let c1   = col(mend)
    " TLogVAR mbeg, mend, opmode, l0, l1, c0, c1
    " TLogVAR text[-1]
    " TLogVAR len(text[-1])
    if opmode == 'block'
        let clen = c1 - c0
        call map(text, 'strpart(v:val, c0, clen)')
    elseif opmode == 'selection'
        if c1 > 1
            let text[-1] = strpart(text[-1], 0, c1 - (a:mode == 'o' || c1 > len(text[-1]) ? 0 : 1))
        endif
        if c0 > 1
            let text[0] = strpart(text[0], c0 - 1)
        endif
    endif
    return text
endf


" For use as an operator. See 'opfunc'.
function! rcom#Operator(type, ...) range "{{{3
    " TLogVAR a:type, a:000
    let sel_save = &selection
    let &selection = "inclusive"
    let reg_save = @@
    try
        if a:0
            let text = rcom#GetSelection("o")
        elseif a:type == 'line'
            let text = rcom#GetSelection("o", "'[", "']", 'lines')
        elseif a:type == 'block'
            let text = rcom#GetSelection("o", "'[", "']", 'block')
        else
            let text = rcom#GetSelection("o", "'[", "']")
        endif
        " TLogVAR text
        let mode = exists('b:rcom_mode') ? b:rcom_mode : ''
        call rcom#EvaluateInBuffer(text, mode)
    finally
        let &selection = sel_save
        let @@ = reg_save
    endtry
endf


function! s:Scratch(type) "{{{3
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal foldmethod=manual
    setlocal foldcolumn=0
    setlocal modifiable
    setlocal nospell
    setf r
    call setline(1, printf('# RCom_vim %s', a:type))
endf


function! s:ScratchBuffer(type, name) "{{{3
    " TLogVAR a:type, a:name
    let bufnr = bufnr(a:name)
    if bufnr != -1 && bufwinnr(bufnr) != -1
        exec 'drop '. a:name
        return 0
    else
        exec g:rcom#{a:type}_cmd .' '. a:name
        if bufnr == -1
            call s:Scratch(a:type)
            return 1
        else
            return 0
        endif
    endif
endf


function! rcom#LogBuffer() "{{{3
    if s:ShouldRemoteSend()
        call remote_foreground('RCOM')
        call remote_send('RCOM', ':call rcom#LogBuffer()<cr>')
    else
        let winnr = winnr()
        " TLogVAR winnr
        try
            call s:ScratchBuffer('log', '__RCom_Log__')
            if g:rcom#log_trim
                let print = 1
            elseif !exists('b:rcom_last_item')
                let b:rcom_last_item = ''
                let print = 1
            else
                let print = 0
            endif
            let items = sort(keys(s:log))
            " TLogVAR items
            for item in items
                if print
                    let text = ['', printf("# %s", item)]
                    let text += split(s:log[item], '\n')
                    call append('$', text)
                    if g:rcom#log_trim
                        call remove(s:log, item)
                    else
                        let b:rcom_last_item = item
                    endif
                elseif b:rcom_last_item == item
                    let print = 1
                endif
            endfor
            norm! Gzb
            redraw
        finally
            exec winnr 'wincmd w'
        endtry
    endif
endf


" Display the log.
command! RComlog call rcom#LogBuffer()

" Reset the log.
command! RComlogreset let s:log = {}


function! rcom#TranscriptBuffer() "{{{3
    if s:ShouldRemoteSend()
        call remote_foreground('RCOM')
        call remote_send('RCOM', ':call rcom#TranscriptBuffer()<cr>')
    else
        if s:ScratchBuffer('transcript', '__RCom_Transcript__')
            set ft=r
        endif
    endif
endf

command! RComtranscript call rcom#TranscriptBuffer()


function! rcom#Transcribe(input, output) "{{{3
    let bufname = bufname('%')
    try
        call rcom#TranscriptBuffer()
        call append(line('$'), strftime('# %c'))
        if !empty(a:input)
            if type(a:input) == 1
                let input = split(a:input, '\n')
            else
                let input = a:input
            endif
            " for i in range(len(input))
            "     let input[i] = (i == 0 ? '> ' : '+ ') . input[i]
            " endfor
            call append(line('$'), input)
        endif
        if !empty(a:output)
            " TLogVAR a:output
            let output = split(a:output, '\n\+')
            for i in range(len(output))
                let output[i] = (i == 0 ? '=> ' : '   ') . output[i]
            endfor
            call append(line('$'), output)
        endif
        call append(line('$'), '')
        norm! Gzb
    finally
        if !empty(bufname)
            exec 'drop '. bufname
        endif
    endtry
endf


let s:sfile = expand('<sfile>:p:h')

" :display: rcom#Initialize(?reuse=g:rcom#reuse)
" Connect to the R interpreter for the current buffer.
" Usually not called by the user.
function! rcom#Initialize(...) "{{{3
    " TLogVAR a:000
    let bn = bufnr('%')
    if !has_key(s:rcom, bn)
        let fn = 'rcom#'. g:rcom#method .'#Initialize'
        " TLogVAR fn
        let r_connection = call(fn, a:000)
        " TLogVAR bn, r_connection
        if r_connection.Connect(g:rcom#reuse)
            let rcom_options = r_connection.Options()
            " TLogVAR rcom_options
            let wd = r_connection.Filename(s:RFilename(expand('%:p:h')))
            let r_lib = r_connection.Filename(s:RFilename(s:sfile) .'/rcom/rcom_vim.R')
            " TLogVAR wd, r_lib
            let rcode = [printf('rcom.options <- %s', s:RDict(rcom_options))]
            if !empty(g:rcom#options)
                call add(rcode, printf('options(%s)', g:rcom#options))
            endif
            let options_reuse = g:rcom#options_reuse_{g:rcom#reuse}
            if !empty(options_reuse)
                call add(rcode, printf('options(%s)', options_reuse))
            endif
            let rcode += [printf('setwd(%s)', string(wd)),
                        \ printf('source(%s)', string(r_lib))
                        \ ]
            call r_connection.Evaluate(rcode, '')
        endif
        exec 'autocmd RCom BufUnload <buffer> call rcom#Quit('. bn .')'
        let s:rcom[bn] = r_connection
    endif
    return s:rcom[bn]
endf


function! s:RFilename(filename) "{{{3
    return substitute(a:filename, '\\', '/', 'g')
endf


function! s:RVal(value) "{{{3
    if type(a:value) == 0        " Number
        return a:value
    elseif type(a:value) == 1    " String
        return string(a:value)
    elseif type(a:value) == 3    " List
        let rlist = map(copy(a:value), 's:RVal(v:val)')
        return printf('c(%s)', join(rlist, ', '))
    elseif type(a:value) == 4    " Dictionary
        return s:RDict(a:value)
    elseif type(a:value) == 5    " Float
        return a:value
    else
        echoerr "RCOM: Unsupport value: ". string(a:value)
    endif
endf


function! s:RDict(dict) "{{{3
    let rv = []
    for [key, val] in items(a:dict)
        call add(rv, printf('%s = %s', string(key), s:RVal(val)))
        unlet val
    endfor
    return printf('list(%s)', join(rv, ', '))
endf


let s:debugged = []

" Toggle the debug status of a function.
function! rcom#Debug(fn) "{{{3
    " TLogVAR fn
    if index(s:debugged, a:fn) == -1
        call rcom#Evaluate(printf('debug(%s)', a:fn))
        call add(s:debugged, a:fn)
        echom "RCom: Debug:" a:fn
        call s:HighlightDebug()
    else
        call rcom#Undebug(a:fn)
    endif
endf


" Undebug a debugged function.
function! rcom#Undebug(fn) "{{{3
    let fn = a:fn
    if empty(fn) && exists('g:loaded_tlib')
        let fn = tlib#input#List('s', 'Select function:', s:debugged)
    endif
    if !empty(fn)
        let i = index(s:debugged, fn)
        if i != -1
            call remove(s:debugged, i)
            echom "RCom: Undebug:" a:fn
        else
            echom "RCom: Not a debugged function?" fn
        endif
        call rcom#Evaluate(printf('undebug(%s)', fn))
        call s:HighlightDebug()
    endif
endf


let s:hl_init = 0

function! s:HighlightDebug() "{{{3
    if s:hl_init
        syntax clear RComDebug
    else
        exec 'hi def link RComDebug' g:rcom#highlight_debug
        let s:hl_init = 1
    endif
    if !empty(s:debugged)
        let debugged = map(copy(s:debugged), 'escape(v:val, ''\'')')
        " TLogVAR debugged
        exec 'syntax match RComDebug /\V\<\('. join(debugged, '\|') .'\)\>/'
    endif
endf


" :display: rcom#Evaluate(rcode, ?mode='')
" rcode can be a string or an array of strings.
" mode can be one of
"   p ... Print the result
"   r ... Always return a result
function! rcom#Evaluate(rcode, ...) "{{{3
    " TLogVAR a:rcode, a:000
    let mode = a:0 >= 1 ? a:1 : ''
    if type(a:rcode) == 3
        let rcode = join(a:rcode, "\n")
    else
        let rcode = a:rcode
    endif
    " TLogVAR a:rcode
    let r_connection = rcom#Initialize(g:rcom#reuse)
    " TLogVAR r_connection
    let value = r_connection.Evaluate(rcode, mode)
    if exists('log') && !empty(log)
        call rcom#Log(log)
    endif
    " TLogVAR value
    return value
endf


" :display: rcom#EvaluateInBuffer(rcode, ?mode='')
" Initialize the current buffer if necessary and evaluate some R code in 
" a running instance of R GUI.
"
" If there is a remote gvim server named RCOM running (see 
" |--servername|), evaluate R code remotely. This won't block the 
" current instance of gvim.
"
" See also |rcom#Evaluate()|.
function! rcom#EvaluateInBuffer(...) range "{{{3
    " TLogVAR a:000
    let len = type(a:1) == 3 ? len(a:1) : 1
    redraw
    " echo
    if s:ShouldRemoteSend()
        call remote_send('RCOM', ':call call("rcom#EvaluateInBuffer", '. string(a:000) .')<cr>')
        echo printf("Sent %d lines to GVim/RCOM", len)
        let rv = ''
    else
        " TLogVAR a:000
        " echo printf("Evaluating %d lines of R code ...", len(a:1))
        call s:Warning("Evaluating R code ...")
        let logn = s:LogN()
        let rv = call('rcom#Evaluate', a:000)
        if bufwinnr('__RCom_Transcript__') != -1 || s:IsRemoteServer()
            call rcom#Transcribe(a:1, rv)
        endif
        " if logn == s:LogN()
        "     redraw
        "     " echo " "
        "     echo printf("Evaluated %d lines", len)
        " endif
        echo " "
        redraw
    endif
    return rv
endf


let &cpo = s:save_cpo
unlet s:save_cpo
