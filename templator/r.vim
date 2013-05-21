" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Last Change: 2012-12-13.
" @Revision:   16

" :doc:
"                                                     *templator-r*
" R Template Set~
" 
" This template set serves as an example for how to use templator.
" 
" Run with:
" 
"     :Templator [*][PATH/]r [NAME] [runit=1]
" 
" The first argument is a name that defaults to "main". The name is used 
" in several locations in the template files.
" 
" If runit is true, the runit library is used for testing. If not, the 
" testthat library is used.


function! g:templator#hooks.r.After(args) dict "{{{3
    let filename = get(a:args, '1', 'main') .'.R'
    " TLogVAR filename
    exec 'buffer' filename
endf


