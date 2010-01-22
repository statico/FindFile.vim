" ============================================================================
" File:        FindFile.vim
" Description: Open file quickly by using autocomplete
" Maintainer:  William Lee <wl1012 at yahoo dot com>
" Last Change: 21 Jan, 2010
" ============================================================================

" SECTION: Script init stuff {{{1
"============================================================
if exists('loaded_find_file')
    finish
endif
if v:version < 700
    echoerr "FindFile: this plugin requires vim >= 7.0"
    finish
endif

let loaded_find_file = 1

" SECTION: Global Settings {{{1
"============================================================
if !exists("g:FindFileIgnore")
    let g:FindFileIgnore = ['*.o', '*.pyc', '*/tmp/*']
endif

" SECTION: Commands {{{1
"============================================================
command! -nargs=* -complete=dir FindFileCache call <SID>CacheDir(<f-args>)
command! -nargs=* -complete=dir FC call <SID>CacheDir(<f-args>)

command! FindFileCacheClear call <SID>CacheClear()
command! FCC call <SID>CacheClear()

command! FindFile call <SID>FindFile()
command! FF call <SID>FindFile()

command! FindFileSplit call <SID>FindFileSplit()
command! FS call <SID>FindFileSplit()

" SECTION: Functions {{{1
"============================================================

" File cache to store the filename
let s:fileCache = {}

" The sorted keys for the dictionary
let s:fileKeys = []

fun! CompleteFile(findstart, base)
  if a:findstart
    return 0
  else
    " TODO: We can definitely do a binary search on the keys instead of
    " doing a linear match.
    for k in s:fileKeys
      let matchExpr = <SID>EscapeChars(a:base)
      if match(k, matchExpr) == 0
        call complete_add({'word': k, 'menu': s:fileCache[k], 'icase' : 1})
      endif
      if complete_check()
        break
      endif
    endfor
    return []
  endif
endfun

fun! <SID>MayComplete(c)
    if pumvisible()
        return a:c
    else
      return "" . a:c . "\<C-X>\<C-O>"
    endif
endfun

fun! <SID>FindFileSplit()
    split
    call <SID>FindFile()
endfun

fun! <SID>FindFile()
  new FindFile
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  " Map the keys for completion:
  " We are remapping keys from ascii 33 (!) to 126 (~)
  let k = 33
  while (k < 127)
    let c = escape(nr2char(k), "\\'|")
    let remapCmd = "inoremap <expr> <buffer> " . c . " <SID>MayComplete('" . c . "')"
    exe remapCmd
    let k = k + 1
  endwhile

  inoremap <buffer> <CR> <ESC>:silent call <SID>EditFile(getline("."))<CR>
  inoremap <buffer> <ESC> <C-[>:silent call <SID>QuitBuff()<CR>
  nnoremap <buffer> <ESC> :silent call <SID>QuitBuff()<CR>
  setlocal completeopt=menuone,longest,preview
  setlocal omnifunc=CompleteFile
  setlocal noignorecase
  startinsert
endfun

fun! <SID>CacheClear()
  let s:fileCache = {}
  let s:fileKeys = []
  echo "FindFile cache cleared."
endfun

fun! <SID>EscapeChars(toEscape)
  return escape(a:toEscape, ". \!\@\#\$\%\^\&\*\(\)\-\=\\\|\~\`\'")
endfun

fun! <SID>CacheDir(...)
  echo "Finding files to cache..."
  for d in a:000
    "Creates the dictionary that will parse all files recursively
    for i in g:FindFileIgnore
      let s = "setlocal wildignore+=" . i
      exe s
    endfor
    let files = glob(d . "/**")
    for i in g:FindFileIgnore
      let s = "setlocal wildignore-=" . i
      exe s
    endfor
    let ctr = 0
    for f in split(files, "\n")
      let fname = fnamemodify(f, ":t")
      let fpath = fnamemodify(f, ":p")
      " We only glob the files, not directory
      if !isdirectory(fpath)
        " If the cache already has this entry, we'll just skip it
        let hasEntry = 0
        while has_key(s:fileCache, fname)
          if s:fileCache[fname] == fpath
            let hasEntry = 1
            break
          endif
          let fnameArr = split(fname, ":")
          if len(fnameArr) > 1
            let fname = fnameArr[0] . ":" . (fnameArr[1] + 1)
          else
            let fname = fname . ":1"
          endif
        endwhile
        if !hasEntry
          let s:fileCache[fname] = fpath
          let ctr = ctr + 1
        endif
      endif
    endfor
    let s:fileKeys = sort(copy(keys(s:fileCache)))
    echo "Found " . ctr . " new files in '" . d . "'. Cache has " . len(s:fileKeys) . " entries."
  endfor
endfun

fun! <SID>QuitBuff()
  silent exe "bd!"
endfun

fun! <SID>EditFile(f)
  " Closes the buffer
  let fileToOpen = a:f
  if has_key(s:fileCache, a:f)
    let fileToOpen = s:fileCache[a:f]
  else
    " We attempt to find the file in the list if it is not a
    " complete key
    let matchExpr = <SID>EscapeChars(a:f)
    for k in s:fileKeys
      if match(k, matchExpr) == 0
        let fileToOpen = s:fileCache[k]
        break
      endif
    endfor
  endif
  if filereadable(fileToOpen)
    silent exe "bd!"
    silent exe "edit " . fileToOpen
    echo "File: " . fileToOpen
  else
    echo "File " . fileToOpen . " not found. Run ':FileFindCache .' to refresh if necessary."
  endif
endfun
