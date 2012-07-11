" screen.vim
" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2012-07-10.
" @Last Change: 2012-07-11.
" @Revision:    37


if !exists(':ScreenShell')
    throw "Screen plugin (http://www.vim.org/scripts/script.php?script_id=2711) is not installed."
endif


if !exists('g:rcom#screen#rterm')
    let g:rcom#screen#rterm = 'Rterm'   "{{{2
endif


if !exists('g:rcom#screen#rterm_args')
    " Command-line arguments passed to Rterm (see |g:rcom#screen#rterm|).
    let g:rcom#screen#rterm_args = '--ess'   "{{{2
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


" type == 1: One-way communication
let s:prototype = {'type': 1}

function! s:prototype.Connect(reuse) dict "{{{3
    let args = [g:rcom#screen#rterm]
    let save = 0
    if g:rcom#screen#save == 2
        let save = 1
    elseif g:rcom#screen#save == 1
        let save = filereadable('.Rdata')
    endif
    call add(args, save ? '--save' : '--no-save')
    call add(args, g:rcom#screen#rterm_args)
    call screen#ScreenShell(join(args, ' '), 'horizontal')
    return 1
endf

function! s:prototype.Disconnect() dict "{{{3
    if exists(':ScreenQuit')
        ScreenQuit
    " else
    "     echom "RCom/Screen: ScreenQuit is undefined. No active session?"
    endif
    return 1
endf

function! s:prototype.Evaluate(rcode, mode) dict "{{{3
    " TLogVAR a:rcode, a:mode
    let rcode = split(a:rcode, '\n')
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
    if !exists('g:ScreenShellSend')
        call self.Connect(g:rcom#reuse)
    endif
    call call(g:ScreenShellSend, [rcode])
    return ''
endf


function! rcom#screen#Initialize(...) "{{{3
    " TLogVAR a:000
    return copy(s:prototype)
endf

