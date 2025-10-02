"set fileencodings=iso-8859-2
set fileencodings=iso-8859-2,utf-8

" color game (not perfect)
":if &term =~ "xterm"
:  if has("terminfo")
:	set t_Co=8
:	set t_Sf=<Esc>[3%p1%dm
:	set t_Sb=<Esc>[4%p1%dm
:  else
:	set t_Co=8
:	set t_Sf=<Esc>[3%dm
:	set t_Sb=<Esc>[4%dm
:  endif
":endif

" * Terminal Settings

" `XTerm', `RXVT', `Gnome Terminal', and `Konsole' all claim to be "xterm";
" `KVT' claims to be "xterm-color":
"test: if &term =~ 'xterm'

  " `Gnome Terminal' fortunately sets $COLORTERM; it needs <BkSpc> and <Del>
  " fixing, and it has a bug which causes spurious "c"s to appear, which can be
  " fixed by unsetting t_RV:
"test:   if $COLORTERM == 'gnome-terminal'
"vku:    execute 'set t_kb=' . nr2char(8)
    " [Char 8 is <Ctrl>+H.]
"vku:    fixdel
"test:     set t_RV=

  " `XTerm', `Konsole', and `KVT' all also need <BkSpc> and <Del> fixing;
  " there's no easy way of distinguishing these terminals from other things
  " that claim to be "xterm", but `RXVT' sets $COLORTERM to "rxvt" and these
  " don't:
"test:   elseif $COLORTERM == ''
"test:     execute 'set t_kb=' . nr2char(8)
"test:     fixdel

  " The above won't work if an `XTerm' or `KVT' is started from within a `Gnome
  " Terminal' or an `RXVT': the $COLORTERM setting will propagate; it's always
  " OK with `Konsole' which explicitly sets $COLORTERM to "".

"test:   endif
"test: endif

if &term == "xterm"
 map <Esc>[1;5D <C-Left>
 map! <Esc>[1;5D <C-Left>
 map <Esc>[1;5C <C-Right>
 map! <Esc>[1;5C <C-Right>
endif	

" if &term == "rxvt"
 map <C-[>Od <C-Left>
 map! <C-[>Od <C-Left>
 map <C-[>Oc <C-Right>
 map! <C-[>Oc <C-Right>
 map <C-[>Ob <C-w><Down>
 map! <C-[>Ob <C-w><Down>
 map <C-[>Oa <C-w><Up>
 map! <C-[>Oa <C-w><Up>
 imap <C-[>Ob <Esc><C-w><Down>
 imap <C-[>Oa <Esc><C-w><Up>
" endif	

map <C-Up> <C-w><Up>
map <C-Down> <C-w><Down>
imap <C-Up> <Esc><C-w><Up><Ins>
imap <C-Down> <Esc><C-w><Down><Ins>

" hardwired terminal color count
set t_Co=16

" incremental search
set incsearch

" ignorecase (or ic) = case insensitive search 
" (override via noignorecase/noic)
set ignorecase

set nobackup
set nowritebackup
set backspace=indent,eol,start
set autoindent
set showcmd
set nowrap
if &t_Co > 2 || has("gui_running")
   syntax on 
   set hlsearch 
endif
set tabstop=4
set shiftwidth=4
set softtabstop=4 
set autowrite
set expandtab
map <F7> :make<CR>
imap <F7> <ESC>:make<CR>
map <F2> :w<CR>
imap <F2> <ESC>:w<CR><Ins>
colorscheme ron
" set statusline=line\ %l,\ col\ %c\ [%p%%]
set statusline=%F%m\ line\ %l/%L,\ col\ %c\ [%p%%]
set laststatus=2

	" vim -b : edit binary using xxd-format!
	augroup Binary
	  au!
	  au BufReadPre  *.bin let &bin=1
	  au BufReadPost *.bin if &bin | %!xxd
	  au BufReadPost *.bin set ft=xxd | endif
	  au BufWritePre *.bin if &bin | %!xxd -r
	  au BufWritePre *.bin endif
	  au BufWritePost *.bin if &bin | %!xxd
	  au BufWritePost *.bin set nomod | endif
	augroup END

	augroup Docbook
	  au!
"	  au BufReadPre  *.xml so ~/vim/docbook.vim
"	  au Filetype xml source ~/vim/docbook.vim
"	  au BufReadPre *.xml source ~/vim/closetag.vim 
"	  au BufReadPre  *.xml set fileencodings=utf-8,iso-88592-2,cp1250
"	  au BufReadPost  *.xml if &fileencoding == "" | set fileencoding="utf-8" | endif
"	  au BufWritePost *.bin if &bin | %!xxd
"	  au BufWritePost *.bin set nomod | endif
	augroup END

" very nice script from http://www.vim.org/scripts/script.php?script_id=13
" for closing unclosed xml/html tags after <C-_>
"au Filetype html,xml,xsl source ~/vim/closetag.vim 

:source $VIMRUNTIME/menu.vim
:set wildmenu
:set cpo-=<
:set wcm=<C-Z>
:map <F10> :emenu <C-Z>


" moje  pridelavky

" special project file behaviour - save to variable
" and open with F10
":autocmd BufRead *.prj let $project=expand("<afile>")

map <C-n> :tnext<CR>
map <Tab> :cnext<CR>
map <S-Tab> :cprev<CR>
map <C-S-CR> :cc<CR>
" open project files
"map <F10> :Prj<CR>
"imap <F10> <ESC>:Prj<CR>
map <F11> :Prjx<CR>
imap <F11> <ESC>:Prjx<CR>
command Prj new $project
command Prjv vnew $project
command Prjx edit $project
menu Project.Files :new $project

" so ~/vim/mydarkblue.vim
" so ~/vim/morning.vim
:color blue

" dump latex addon fix
let g:Imap_FreezeImap=1

set whichwrap=b,s,<,>,[,]
set viminfo='50,<100,%

" return to latest pos after file is open
au BufWinEnter * '"

" id utils for movement by identifier?
map _u :call ID_search()<Bar>execute "/\\<" . g:word . "\\>"<CR>
map _n :n<Bar>execute "/\\<" . g:word . "\\>"<CR>
function! ID_search()
	let g:word = expand("<cword>")
	let x = system("lid --key=none ". g:word)
	let x = substitute(x, "\n", " ", "g")
	execute "next " . x
endfun

"use id-utils (see info 'ID database')
":set grepprg=lid\ -Rgrep\ -s
":set grepformat=%f:%l:%m

" enable mouse in 'all' windows
set mouse=a

" open error window
":cwindow

map <F3> :vs<Return><Return>
map <F4> :q
imap <F4> <Esc>:q

set sidescroll=5
set listchars+=precedes:<,extends:>

" in visual mode / search selection in whole text
:vmap / y/<C-R>"<CR>

" block transition insert/replace mode via Ins!
imap <Ins> <Nop>

" keys for my call-flow diagrams
imap ,ca <call src="" dst="" desc=""/><esc>bbbbbla

nmap <C-@> :Lid <C-R>=expand("<cword>")<CR><CR>
map <F1> <Nop>
imap <F1> <Nop>
vmap <F1> <Nop>
map <F1> :stag <C-R>=expand("<cword>")<CR><CR>

" don't beep
set noeb
set vb t_vb=""

" needed with new vim:
au BufReadPre  *.c set cindent
au BufReadPre  *.cxx set cindent
au BufReadPre  *.cpp set cindent
au BufReadPre  *.h set cindent

" Clipboard problems on X with debian testing
" is possible to solve with xclip utility
" copy selection (http://www.vim.org/tips/tip.php?tip_id=964)
"vmap <F6> :!xclip -f -sel clip<CR>
"vmap <C-C> :!xclip -f -sel clip<CR>
vmap <C-C> :w !xclip -sel clip<CR><CR>
" paste selection
imap <C-V> <Esc>:-1r !xclip -o -sel clip<CR>i
"vmap <C-V> :-1r !xclip -o -sel clip<CR> 

"experimental copy 'partial' rows to clipboard
":vmap <C-C> y:new<CR>p:1,$!xclip -f -sel clip<CR>:q!<CR>

" kick off stupid windows key uppercasing words
map <C-[>[29~ <Esc>

" show empty trailling chars
match Todo /\s\+$/
set modeline
