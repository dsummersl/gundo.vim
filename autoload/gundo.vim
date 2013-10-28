" ============================================================================
" File:        gundo.vim
" Description: vim global plugin to visualize your undo tree
" Maintainer:  Steve Losh <steve@stevelosh.com>
" License:     GPLv2+ -- look it up.
" Notes:       Much of this code was thiefed from Mercurial, and the rest was
"              heavily inspired by scratch.vim and histwin.vim.
"
" ============================================================================


"{{{ Init

if v:version < '703'"{{{
    function! s:GundoDidNotLoad()
        echohl WarningMsg|echomsg "Gundo unavailable: requires Vim 7.3+"|echohl None
    endfunction
    command! -nargs=0 GundoToggle call s:GundoDidNotLoad()
    finish
endif"}}}

if !exists('g:gundo_width')"{{{
    let g:gundo_width = 45
endif"}}}
if !exists('g:gundo_preview_height')"{{{
    let g:gundo_preview_height = 15
endif"}}}
if !exists('g:gundo_preview_bottom')"{{{
    let g:gundo_preview_bottom = 0
endif"}}}
if !exists('g:gundo_right')"{{{
    let g:gundo_right = 0
endif"}}}
if !exists('g:gundo_help')"{{{
    let g:gundo_help = 1
endif"}}}
if !exists("g:gundo_map_move_older")"{{{
    let g:gundo_map_move_older = 'j'
endif"}}}
if !exists("g:gundo_map_move_newer")"{{{
    let g:gundo_map_move_newer = 'k'
endif"}}}
if !exists("g:gundo_close_on_revert")"{{{
    let g:gundo_close_on_revert = 0
endif"}}}
if !exists("g:gundo_prefer_python3")"{{{
    let g:gundo_prefer_python3 = 0
endif"}}}
if !exists("g:gundo_auto_preview")"{{{
    let g:gundo_auto_preview = 1
endif"}}}
if !exists("g:gundo_verbose_graph")"{{{
    let g:gundo_verbose_graph = 0
endif"}}}

let s:has_supported_python = 0
if g:gundo_prefer_python3 && has('python3')"{{{
    let s:has_supported_python = 2
elseif has('python')"
    let s:has_supported_python = 1
endif

if !s:has_supported_python
    function! s:GundoDidNotLoad()
        echohl WarningMsg|echomsg "Gundo requires Vim to be compiled with Python 2.4+"|echohl None
    endfunction
    command! -nargs=0 GundoToggle call s:GundoDidNotLoad()
    finish
endif"}}}

let s:plugin_path = escape(expand('<sfile>:p:h'), '\')
"}}}

"{{{ Gundo utility functions

function! s:GundoGoToWindowForBufferName(name)"{{{
    if bufwinnr(bufnr(a:name)) != -1
        exe bufwinnr(bufnr(a:name)) . "wincmd w"
        return 1
    else
        return 0
    endif
endfunction"}}}

function! s:GundoIsVisible()"{{{
    if bufwinnr(bufnr("__Gundo__")) != -1 || bufwinnr(bufnr("__Gundo_Preview__")) != -1
        return 1
    else
        return 0
    endif
endfunction"}}}

function! s:GundoInlineHelpLength()"{{{
    if g:gundo_help
        return 10
    else
        return 0
    endif
endfunction"}}}

"}}}

"{{{ Gundo buffer settings

function! s:GundoMapGraph()"{{{
    exec 'nnoremap <script> <silent> <buffer> ' . g:gundo_map_move_older . " :call <sid>GundoMove(1)<CR>"
    exec 'nnoremap <script> <silent> <buffer> ' . g:gundo_map_move_newer . " :call <sid>GundoMove(-1)<CR>"
    nnoremap <script> <silent> <buffer> <CR>          :call <sid>GundoRevert()<CR>
    nnoremap <script> <silent> <buffer> o             :call <sid>GundoRevert()<CR>
    nnoremap <script> <silent> <buffer> <down>        :call <sid>GundoMove(1)<CR>
    nnoremap <script> <silent> <buffer> <up>          :call <sid>GundoMove(-1)<CR>
    nnoremap <script> <silent> <buffer> gg            gg:call <sid>GundoMove(1)<CR>
    nnoremap <script> <silent> <buffer> P             :call <sid>GundoPlayTo()<CR>
    nnoremap <script> <silent> <buffer> d             :call <sid>GundoRenderPatchdiff()<CR>
    nnoremap <script> <silent> <buffer> /             :call <sid>GundoPython('GundoSearch')<CR>
    nnoremap <script> <silent> <buffer> n             :call <sid>GundoPython('GundoNextMatch')<CR>
    nnoremap <script> <silent> <buffer> N             :call <sid>GundoPython('GundoPrevMatch')<CR>
    nnoremap <script> <silent> <buffer> r             :call <sid>GundoRenderPreview()<CR>
    nnoremap <script> <silent> <buffer> q             :call <sid>GundoClose()<CR>
    cabbrev  <script> <silent> <buffer> q             call <sid>GundoClose()
    cabbrev  <script> <silent> <buffer> quit          call <sid>GundoClose()
    nnoremap <script> <silent> <buffer> <2-LeftMouse> :call <sid>GundoMouseDoubleClick()<CR>
endfunction"}}}

function! s:GundoMapPreview()"{{{
    nnoremap <script> <silent> <buffer> q     :call <sid>GundoClose()<CR>
    cabbrev  <script> <silent> <buffer> q     call <sid>GundoClose()
    cabbrev  <script> <silent> <buffer> quit  call <sid>GundoClose()
endfunction"}}}

function! s:GundoSettingsGraph()"{{{
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal filetype=gundo
    setlocal nolist
    setlocal nonumber
    setlocal norelativenumber
    setlocal nowrap
    call s:GundoSyntaxGraph()
    call s:GundoMapGraph()
endfunction"}}}

function! s:GundoSettingsPreview()"{{{
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal filetype=diff
    setlocal nonumber
    setlocal norelativenumber
    setlocal nowrap
    setlocal foldlevel=20
    setlocal foldmethod=diff
    call s:GundoMapPreview()
endfunction"}}}

function! s:GundoSyntaxGraph()"{{{
    let b:current_syntax = 'gundo'

    syn match GundoCurrentLocation '@'
    syn match GundoHelp '\v^".*$'
    syn match GundoNumberField '\v\[[0-9]+\]'
    syn match GundoNumber '\v[0-9]+' contained containedin=GundoNumberField

    hi def link GundoCurrentLocation Keyword
    hi def link GundoHelp Comment
    hi def link GundoNumberField Comment
    hi def link GundoNumber Identifier
endfunction"}}}

"}}}

"{{{ Gundo buffer/window management

function! s:GundoResizeBuffers(backto)"{{{
    call s:GundoGoToWindowForBufferName('__Gundo__')
    exe "vertical resize " . g:gundo_width

    call s:GundoGoToWindowForBufferName('__Gundo_Preview__')
    exe "resize " . g:gundo_preview_height

    exe a:backto . "wincmd w"
endfunction"}}}

function! s:GundoOpenGraph()"{{{
    let existing_gundo_buffer = bufnr("__Gundo__")

    if existing_gundo_buffer == -1
        call s:GundoGoToWindowForBufferName('__Gundo_Preview__')
        exe "new __Gundo__"
        if g:gundo_preview_bottom
            if g:gundo_right
                wincmd L
            else
                wincmd H
            endif
        endif
        call s:GundoResizeBuffers(winnr())
    else
        let existing_gundo_window = bufwinnr(existing_gundo_buffer)

        if existing_gundo_window != -1
            if winnr() != existing_gundo_window
                exe existing_gundo_window . "wincmd w"
            endif
        else
            call s:GundoGoToWindowForBufferName('__Gundo_Preview__')
            if g:gundo_preview_bottom
                if g:gundo_right
                    exe "botright vsplit +buffer" . existing_gundo_buffer
                else
                    exe "topleft vsplit +buffer" . existing_gundo_buffer
                endif
            else
                exe "split +buffer" . existing_gundo_buffer
            endif
            call s:GundoResizeBuffers(winnr())
        endif
    endif
    if exists("g:gundo_tree_statusline")
        let &l:statusline = g:gundo_tree_statusline
    endif
endfunction"}}}

function! s:GundoOpenPreview()"{{{
    let existing_preview_buffer = bufnr("__Gundo_Preview__")

    if existing_preview_buffer == -1
        if g:gundo_preview_bottom
            exe "botright new __Gundo_Preview__"
        else
            if g:gundo_right
                exe "botright vnew __Gundo_Preview__"
            else
                exe "topleft vnew __Gundo_Preview__"
            endif
        endif
    else
        let existing_preview_window = bufwinnr(existing_preview_buffer)

        if existing_preview_window != -1
            if winnr() != existing_preview_window
                exe existing_preview_window . "wincmd w"
            endif
        else
            if g:gundo_preview_bottom
                exe "botright split +buffer" . existing_preview_buffer
            else
                if g:gundo_right
                    exe "botright vsplit +buffer" . existing_preview_buffer
                else
                    exe "topleft vsplit +buffer" . existing_preview_buffer
                endif
            endif
        endif
    endif
    if exists("g:gundo_preview_statusline")
        let &l:statusline = g:gundo_preview_statusline
    endif
endfunction"}}}

function! s:GundoClose()"{{{
    if s:GundoGoToWindowForBufferName('__Gundo__')
        quit
    endif

    if s:GundoGoToWindowForBufferName('__Gundo_Preview__')
        quit
    endif

    exe bufwinnr(g:gundo_target_n) . "wincmd w"
endfunction"}}}

function! s:GundoOpen()"{{{
    if !exists('g:gundo_py_loaded')
        if s:has_supported_python == 2 && g:gundo_prefer_python3
            exe 'py3file ' . s:plugin_path . '/gundo.py'
            python3 initPythonModule()
        else
            exe 'pyfile ' . s:plugin_path . '/gundo.py'
            python initPythonModule()
        endif

        if !s:has_supported_python
            function! s:GundoDidNotLoad()
                echohl WarningMsg|echomsg "Gundo unavailable: requires Vim 7.3+"|echohl None
            endfunction
            command! -nargs=0 GundoToggle call s:GundoDidNotLoad()
            call s:GundoDidNotLoad()
            return
        endif

        let g:gundo_py_loaded = 1
    endif

    " Save `splitbelow` value and set it to default to avoid problems with
    " positioning new windows.
    let saved_splitbelow = &splitbelow
    let &splitbelow = 0

    call s:GundoOpenPreview()
    exe bufwinnr(g:gundo_target_n) . "wincmd w"

    call s:GundoRenderGraph()
    call s:GundoRenderPreview()

    " Restore `splitbelow` value.
    let &splitbelow = saved_splitbelow
endfunction"}}}

function! s:GundoToggle()"{{{
    if s:GundoIsVisible()
        call s:GundoClose()
    else
        let g:gundo_target_n = bufnr('')
        let g:gundo_target_f = @%
        call s:GundoOpen()
    endif
endfunction"}}}

function! s:GundoShow()"{{{
    if !s:GundoIsVisible()
        let g:gundo_target_n = bufnr('')
        let g:gundo_target_f = @%
        call s:GundoOpen()
    endif
endfunction"}}}

function! s:GundoHide()"{{{
    if s:GundoIsVisible()
        call s:GundoClose()
    endif
endfunction"}}}

"}}}

"{{{ Gundo mouse handling

function! s:GundoMouseDoubleClick()"{{{
    let start_line = getline('.')

    if stridx(start_line, '[') == -1
        return
    else
        call s:GundoRevert()
    endif
endfunction"}}}

"}}}

"{{{ Gundo movement

function! s:GundoMove(direction) range"{{{
    if s:has_supported_python == 2 && g:gundo_prefer_python3
        exec "python3 GundoMove(". a:direction .",". v:count1 .")"
    else
        exec "python GundoMove(". a:direction .",". v:count1 .")"
    endif
endfunction"}}}

"}}}

"{{{ Gundo rendering

function! s:GundoRenderGraph()"{{{
    if s:has_supported_python == 2 && g:gundo_prefer_python3
        python3 GundoRenderGraph()
    else
        python GundoRenderGraph()
    endif
endfunction"}}}

function! s:GundoRenderPatchdiff()"{{{
    if s:has_supported_python == 2 && g:gundo_prefer_python3
        python3 GundoRenderPatchdiff()
    else
        python GundoRenderPatchdiff()
    endif
endfunction"}}}

function! s:GundoPython(fn)"{{{
    if s:has_supported_python == 2 && g:gundo_prefer_python3
        exec "python3 ". a:fn ."()"
    else
        exec "python ". a:fn ."()"
    endif
endfunction"}}}

function! s:GundoRenderPreview()"{{{
    if s:has_supported_python == 2 && g:gundo_prefer_python3
        python3 GundoRenderPreview()
    else
        python GundoRenderPreview()
    endif
endfunction"}}}

function! s:GundoRenderChangePreview()"{{{
    if s:has_supported_python == 2 && g:gundo_prefer_python3
        python3 GundoRenderChangePreview()
    else
        python GundoRenderChangePreview()
    endif
endfunction"}}}

"}}}

"{{{ Gundo undo/redo

function! s:GundoRevert()"{{{
    if s:has_supported_python == 2 && g:gundo_prefer_python3
        python3 GundoRevert()
    else
        python GundoRevert()
    endif
endfunction"}}}

function! s:GundoPlayTo()"{{{
    if s:has_supported_python == 2 && g:gundo_prefer_python3
        python3 GundoPlayTo()
    else
        python GundoPlayTo()
    endif
endfunction"}}}

"}}}

"{{{ Misc

function! gundo#GundoToggle()"{{{
    call s:GundoToggle()
endfunction"}}}

function! gundo#GundoShow()"{{{
    call s:GundoShow()
endfunction"}}}

function! gundo#GundoHide()"{{{
    call s:GundoHide()
endfunction"}}}

function! gundo#GundoRenderGraph()"{{{
    call s:GundoRenderGraph()
endfunction"}}}

" automatically reload Gundo buffer if open
function! s:GundoRefresh()"{{{
  " abort when there were no changes

  " abort if our b:gundoChangedtick doens't exist
  if !exists('b:gundoChangedtick')
    return
  endif

  if b:gundoChangedtick == b:changedtick | return | endif
  let b:gundoChangedtick = b:changedtick

  let gundoWin    = bufwinnr('__Gundo__')
  let gundoPreWin = bufwinnr('__Gundo_Preview__')
  let currentWin  = bufwinnr('%')

  " abort if Gundo is closed or is current window
  if (gundoWin == -1) || (gundoPreWin == -1) || (gundoWin == currentWin) || (gundoPreWin == currentWin)
    return
  endif

  :GundoRenderGraph

  " switch back to previous window
  execute currentWin . 'wincmd w'
endfunction"}}}

augroup GundoAug
    autocmd!
    autocmd BufNewFile __Gundo__ call s:GundoSettingsGraph()
    autocmd BufNewFile __Gundo_Preview__ call s:GundoSettingsPreview()
    autocmd CursorHold * call s:GundoRefresh()
    autocmd BufEnter * let b:gundoChangedtick = 0
augroup END

"}}}
