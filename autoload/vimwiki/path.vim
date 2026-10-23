" vim:tabstop=2:shiftwidth=2:expandtab:textwidth=99
" Vimwiki autoload plugin file
" Description: Path manipulation functions
" Home: https://github.com/vimwiki/vimwiki/



function! vimwiki#path#chomp_slash(str) abort
  " Remove trailing path separators
  return substitute(a:str, '/\+$', '', '')
endfunction


function! vimwiki#path#is_equal(p1, p2) abort
  return a:p1 ==# a:p2
endfunction


function! vimwiki#path#normalize(path) abort
  " Collapse Sections: like /a/b/../c to /a/c and /a/b/./c to /a/b/c
  let path = a:path
  while 1
    let intermediateResult = substitute(path, '/[^/]\+/\.\.', '', '')
    let result = substitute(intermediateResult, '/\./', '/', '')
    if result ==# path
      break
    endif
    let path = result
  endwhile
  return result
endfunction


function! vimwiki#path#path_norm(path) abort
  " Collapse repeated path separators and resolve symlinks
  " return if scp
  if a:path =~# '^scp:' | return a:path | endif
  " treat multiple consecutive slashes as one path separator
  let path = substitute(a:path, '/\+', '/', 'g')
  " ensure that we are not fooled by a symbolic link
  return resolve(path)
endfunction


function! vimwiki#path#is_link_to_dir(link) abort
  " Check: if link is to a directory
  " It should end with /.
  return a:link =~# '\m/$'
endfunction


function! vimwiki#path#abs_path_of_link(link) abort
  " Get: absolute path <- path relative to current file
  return vimwiki#path#normalize(expand('%:p:h').'/'.a:link)
endfunction


function! vimwiki#path#path_common_pfx(path1, path2) abort
  " Returns: longest common path prefix of 2 given paths.
  " Ex: '~/home/usrname/wiki', '~/home/usrname/wiki/shmiki' => '~/home/usrname/wiki'
  let p1 = split(a:path1, '/', 1)
  let p2 = split(a:path2, '/', 1)

  let idx = 0
  let minlen = min([len(p1), len(p2)])
  while (idx < minlen) && vimwiki#path#is_equal(p1[idx], p2[idx])
    let idx = idx + 1
  endwhile
  if idx == 0
    return ''
  else
    return join(p1[: idx-1], '/')
  endif
endfunction


function! vimwiki#path#wikify_path(path) abort
  " Convert: path -> full resolved slashed path
  let result = resolve(fnamemodify(a:path, ':p'))
  let result = vimwiki#path#chomp_slash(result)
  return result
endfunction


function! vimwiki#path#current_wiki_file() abort
  " Return: Current file path relative
  return vimwiki#path#wikify_path(expand('%:p'))
endfunction


function! vimwiki#path#relpath(dir, file) abort
  " Return: the relative path from a:dir to a:file
  " Check if dir here ('.') -> return file
  if empty(a:dir) || a:dir =~# '^\./\?$'
    return a:file
  endif
  " Expand paths
  let s_dir = expand(a:dir)
  let s_file = expand(a:file)

  " Split path
  let dir = split(s_dir, '/')
  let file = split(s_file, '/')

  " Shorten loop till equality
  while (len(dir) > 0 && len(file) > 0) && vimwiki#path#is_equal(dir[0], file[0])
    call remove(dir, 0)
    call remove(file, 0)
  endwhile

  " Return './' if nothing left
  if empty(dir) && empty(file)
    return './'
  endif

  " Build path segment
  let segments = []
  for segment in dir
    let segments += ['..']
  endfor
  for segment in file
    let segments += [segment]
  endfor

  " Join segments
  let result_path = join(segments, '/')
  if a:file =~# '\m/$'
    let result_path .= '/'
  endif

  return result_path
endfunction


function! vimwiki#path#mkdir(path, ...) abort
  " Mkdir:
  " if the optional argument provided and nonzero,
  " it will ask before creating a directory
  " returns: 1 iff directory exists or successfully created
  let path = expand(a:path)

  if path =~# '^scp:'
    " we can not do much, so let's pretend everything is ok
    return 1
  endif

  if isdirectory(path)
    return 1
  else
    let path = vimwiki#path#chomp_slash(path)
    if a:0 && a:1 && input('Vimwiki: Make new directory: '.path."\n [y]es/[N]o? ") !~? '^y'
      return 0
    endif

    call mkdir(path, 'p')
    return 1
  endif
endfunction


function! vimwiki#path#is_absolute(path) abort
  " Check: if path is absolute
  let res=0

  " Match '/' or '~/'
  let res += a:path =~# '\m^/\|\~/'

  " Do not prepend root_path to scp files
  " See: https://vim.fandom.com/wiki/Editing_remote_files_via_scp_in_vim
  let res += a:path =~# '\m^scp:'

  return res
endfunction



function! s:get_wikifile_link(wikifile) abort
  return vimwiki#base#subdir(vimwiki#vars#get_wikilocal('path'), a:wikifile).
    \ fnamemodify(a:wikifile, ':t:r')
endfunction

function! vimwiki#path#PasteLink(wikifile) abort
  call append(line('.'), '[[/'.s:get_wikifile_link(a:wikifile).']]')
endfunction


function! vimwiki#path#join_path(directory, file) abort
  let directory = substitute(a:directory, '\m/\+$', '', '')
  let file = substitute(a:file, '\m^/\+', '', '')
  return directory . '/' . file
endfunction
