" rcom.vim -- Execute R code via rcom
" @Author:      Thomas Link (mailto:micathom AT gmail com?subject=[vim])
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2010-02-23.
" @Last Change: 2012-07-20.
" @Revision:    151
" GetLatestVimScripts: 2991 0 :AutoInstall: rcom.vim

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:loaded_rcom')
    let g:loaded_rcom = 3
endif


if !exists('g:rcom_r_plugin_compatibility')
    let g:rcom_r_plugin_compatibility = 0   "{{{2
endif


if g:rcom_r_plugin_compatibility

    let g:rcom_map = "<plug>rcom_eval"
    let g:rcom_mapp = "<plug>rcom_evalprint"
    let g:rcom_mapop = "<plug>rcom_op"
    exec 'nnoremap <buffer> <localleader>rp viw<plug>rcom_evalprint
    nnoremap <buffer> <localleader>rt :call rcom#Keyword()<cr>
    nnoremap <buffer> <localleader>bb <plug>rcom_op

else

    if !exists('g:rcom_map')
        " The map for rcom-related maps in normal, insert, and visual mode.
        " Set this to "", to prevent rcom from defining maps.
        let g:rcom_map = "<c-cr>"   "{{{2
    endif

    if !exists('g:rcom_mapp')
        " The map for rcom-related maps that print the result.
        " Set this to "", to prevent rcom from defining maps.
        let g:rcom_mapp = "<c-s-cr>"   "{{{2
    endif

    if !exists('g:rcom_mapop')
        " The rcom operator map.
        " Set this to "", to prevent rcom from defining maps.
        "
        " This defines the following maps (where # represents the value of 
        " g:rcom_mapop):
        "
        "     #{motion} ... Operator
        "     #.        ... Evaluate the current line (normal mode)
        "     [visual]# ... Evaluate the visual area
        "     #p        ... Toggle printing for the above maps
        "     #d        ... Toggle a function's debug status
        "     #l        ... Open the log window
        "     ##        ... Evaluate the |maparg| previously mapped to #
        let g:rcom_mapop = "+"   "{{{2
    endif

endif


let b:rcom_mode = ''

if !exists('b:tskelHyperComplete')
    let b:tskelHyperComplete = {'use_omnifunc': 1, 'use_completefunc': 1, 'scan_words': 1, 'scan_tags': 1}
endif


if empty(&omnifunc)
    setlocal omnifunc=rcom#Complete
endif

" :tagprefix rcom-map-:

" See |rcom#Keyword()| and |K|.
nnoremap <buffer> K :call rcom#Keyword()<cr>

" Inspect an R object -- see |rcom#Info()|.
nnoremap <buffer> <LocalLeader>K :call rcom#Info()<cr>


" if !hasmapto(':call rcom#EvaluateInBuffer(', 'n')
if !empty(g:rcom_map)
    " exec 'nnoremap <buffer> '. g:rcom_map .' vip:call rcom#EvaluateInBuffer(getline(''.''), "")<cr>}'
    exec 'nnoremap <buffer> '. g:rcom_map .' :call rcom#EvaluateInBuffer(getline(''.''), "")<cr>j'
endif
if !empty(g:rcom_mapp)
    " exec 'nnoremap <buffer> '. g:rcom_mapp .' vip:call rcom#EvaluateInBuffer(getline(''.''), "p")<cr>}'
    exec 'nnoremap <buffer> '. g:rcom_mapp .' :call rcom#EvaluateInBuffer(getline(''.''), "p")<cr>j'
endif
" endif
" if !hasmapto(':call rcom#EvaluateInBuffer(', 'i')
if !empty(g:rcom_map)
    exec 'inoremap <buffer> '. g:rcom_map .' <c-\><c-o>:call rcom#EvaluateInBuffer(getline(''.''), "")<cr>'
endif
if !empty(g:rcom_mapp)
    exec 'inoremap <buffer> '. g:rcom_mapp .' <c-\><c-o>:call rcom#EvaluateInBuffer(getline(''.''), "p")<cr>'
endif
" endif
" if !hasmapto(':call rcom#EvaluateInBuffer(', 'vsx')
if !empty(g:rcom_map)
    exec 'vnoremap <buffer> '. g:rcom_map .' :call rcom#EvaluateInBuffer(rcom#GetSelection("v"), "")<cr>'
endif
if !empty(g:rcom_mapp)
    exec 'vnoremap <buffer> '. g:rcom_mapp .' :call rcom#EvaluateInBuffer(rcom#GetSelection("v"), "p")<cr>'
endif
" endif


if !empty(g:rcom_mapop)
    if empty(maparg(g:rcom_mapop))
        exec 'nnoremap <buffer> '. g:rcom_mapop . g:rcom_mapop .' '. g:rcom_mapop
    else
        exec 'nnoremap <buffer> '. g:rcom_mapop . g:rcom_mapop .' '. maparg(g:rcom_mapop)
    endif
    exec 'nnoremap <buffer> '. g:rcom_mapop .' :set opfunc=rcom#Operator<cr>g@'
    exec 'nnoremap <buffer> '. g:rcom_mapop .'. :call rcom#EvaluateInBuffer(getline(''.''), b:rcom_mode)<cr>'
    exec 'xnoremap <buffer> '. g:rcom_mapop .' :call rcom#EvaluateInBuffer(rcom#GetSelection("v"), b:rcom_mode)<cr>'
    exec 'nnoremap <buffer> '. g:rcom_mapop .'p :let b:rcom_mode = b:rcom_mode == "p" ? "" : "p" \| redraw \| echom "RCom: Printing turned ". (b:rcom_mode == "p" ? "on" : "off")<cr>'
    exec 'nnoremap <buffer> '. g:rcom_mapop .'d :call rcom#Debug(expand("<cword>"))<cr>'
    exec 'vnoremap <buffer> '. g:rcom_mapop .'d ""p:call rcom#Debug(@")<cr>'
    exec 'nnoremap <buffer> '. g:rcom_mapop .'l :call rcom#LogBuffer()<cr>'
    exec 'nnoremap <buffer> '. g:rcom_mapop .'t :call rcom#TranscriptBuffer()<cr>'
endif


" :display: RDebug [FUNCTION]
" Buffer-local command.
" Debug the function under cursor.
command! -buffer -nargs=? RDebug    call rcom#Debug(empty(<q-args>) ? expand("<cword>") : <q-args>)

" :display: RUndebug [FUNCTION]
" Buffer-local command.
" Undebug the function under cursor.
command! -buffer -nargs=? RUndebug  call rcom#Undebug(empty(<q-args>) ? (exists('g:loaded_tlib') ? '' : expand("<cword>")) : <q-args>)


" if !hasmapto(':call rcom#EvaluateInBuffer(', 'n')
"     nnoremap <buffer> <LocalLeader>r :call rcom#EvaluateInBuffer(getline('.'), "")<cr>j
"     nnoremap <buffer> <LocalLeader>R :call rcom#EvaluateInBuffer(getline('.'), "p")<cr>j
" endif
" if !hasmapto(':call rcom#EvaluateInBuffer(', 'i')
"     inoremap <buffer> <LocalLeader>r <c-\><c-o>:call rcom#EvaluateInBuffer(getline('.'), "")<cr>
"     inoremap <buffer> <LocalLeader>R <c-\><c-o>:call rcom#EvaluateInBuffer(getline('.'), "p")<cr>
" endif
" if !hasmapto(':call rcom#EvaluateInBuffer(', 'vsx')
"     vnoremap <buffer> <LocalLeader>r :call rcom#EvaluateInBuffer(rcom#GetSelection("v"), "")<cr>gv
"     vnoremap <buffer> <LocalLeader>R :call rcom#EvaluateInBuffer(rcom#GetSelection("v"), "p")<cr>gv
" endif


let &cpo = s:save_cpo
unlet s:save_cpo
