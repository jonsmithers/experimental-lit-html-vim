" Description: Vim lit-html indent file
" Language: JavaScript
" Maintainer: Jon Smithers <mail@jonsmithers.link>

" Save the current JavaScript indentexpr.
let b:litHtmlOriginalIndentExpression = &indentexpr

" import xml indent
if exists('b:did_indent')
  let s:did_indent=b:did_indent
  unlet b:did_indent
endif
exe 'runtime! indent/html.vim'
if exists('s:did_indent')
  let b:did_indent=s:did_indent
endif

" import css indent
if exists('b:did_indent')
  let s:did_indent=b:did_indent
  unlet b:did_indent
endif
exe 'runtime! indent/css.vim'
if exists('s:did_indent')
  let b:did_indent=s:did_indent
endif

setlocal indentexpr=ComputeLitHtmlIndent()

" JS indentkeys
setlocal indentkeys=0{,0},0),0],0\,,!^F,o,O,e
" XML indentkeys
setlocal indentkeys+=*<Return>,<>>,<<>,/
" lit-html indentkeys
setlocal indentkeys+=`

" Multiline end tag regex (line beginning with '>' or '/>')
let s:endtag = '^\s*\/\?>\s*;\='

" Get syntax stack at StartOfLine
fu! VHTL_SynSOL(lnum)
  let l:col = match(getline(line('.')), '\S')
  if (l:col == -1)
    return []
  endif
  return map(synstack(a:lnum, l:col+1), "synIDattr(v:val, 'name')")
endfu

" Get syntax stack at EndOfLine
fu! VHTL_SynEOL(lnum)
  if (a:lnum < 1)
    return []
  endif
  let l:col = strlen(getline(a:lnum))
  return map(synstack(a:lnum, l:col), "synIDattr(v:val, 'name')")
endfu

fu! IsSynstackCss(synstack)
  return get(a:synstack, -1) =~# '^css'
endfu

" Does synstack end with an xml syntax attribute
fu! IsSynstackHtml(synstack)
  return get(a:synstack, -1) =~# '^html'
endfu

fu! IsSynstackJs(synstack)
  return get(a:synstack, -1) =~# '^js'
endfu

fu! VHTL_isSynstackInsideLitHtml(synstack)
  for l:syntaxAttribute in reverse(copy((a:synstack)))
    if (l:syntaxAttribute ==# 'litHtmlRegion')
      return v:true
    endif
  endfor
  return v:false
endfu

fu! IsSynstackInsideJsx(synstack)
  for l:syntaxAttribute in reverse(copy((a:synstack)))
    if (l:syntaxAttribute =~# '^jsx')
      return v:true
    endif
  endfor
  return v:false
endfu

fu! VHTL_closesJsExpression(str)
  return (VHTL_getBracketDepthChange(a:str) < 0)
endfu
fu! VHTL_getBracketDepthChange(str)
  let l:depth=0
  for l:char in split(a:str, '\zs')
    if (l:char ==# '{')
      let l:depth += 1
    elseif (l:char ==# '}')
      let l:depth -=1
    endif
  endfor
  return l:depth
endfu

fu! VHTL_startsWithTemplateEnd(linenum)
  return (getline(a:linenum)) =~# '^\s*`'
endfu

fu! VHTL_opensTemplate(line)
  let l:index = 0
  let l:depth = 0
  while v:true
    let [l:term, l:index, l:trash] = matchstrpos(a:line, '\Mhtml`\|\\`\|`', l:index)
    if (l:index == -1)
      return (l:depth > 0)
    endif
    if (l:term ==# 'html`')
      let l:index += len('html`')
      let l:depth += 1
    elseif(l:term ==# '`')
      let l:index += len('`')
      if (l:depth > 0)
        let l:depth -= 1
      endif
    endif
  endwhile
endfu

fu! VHTL_closesTemplate(line)
  let l:index = 0
  let l:depth = 0
  while v:true
    let [l:term, l:index, l:trash] = matchstrpos(a:line, '\Mhtml`\|\\`\|`', l:index)
    if (l:index == -1)
      return v:false
    endif
    if (l:term ==# 'html`')
      let l:index += len('html`')
      let l:depth += 1
    elseif(l:term ==# '`')
      let l:index += len('`')
      let l:depth -= 1
      if (l:depth < 0)
        return v:true
      endif
    endif
  endwhile
endfu

fu! VHTL_closesTag(line)
  return (-1 != match(a:line, '^\s*<\/'))
  " todo: what about <div></div></div> ?
endfu

fu! VHTL_getHtmlTemplateDepthChange(line)
  let l:templateOpeners = VHTL_countMatches(a:line, 'html`')
  let l:escapedTics     = VHTL_countMatches(a:line, '\M\\`')
  let l:templateClosers = VHTL_countMatches(a:line, '`') - l:templateOpeners - l:escapedTics
  let l:depth = l:templateOpeners - l:templateClosers
  return l:depth
endfu

fu! VHTL_countMatches(string, pattern)
  let l:count = 0
  let l:lastMatch = -1
  while v:true
    let l:lastMatch = match(a:string, a:pattern, l:lastMatch+1)
    if (-1 == l:lastMatch)
      return l:count
    else
      let l:count += 1
    endif
  endwhile
endfu

function! s:SynAt(l,c) " from $VIMRUNTIME/indent/javascript.vim
  let byte = line2byte(a:l) + a:c - 1
  let pos = index(s:synid_cache[0], byte)
  if pos == -1
    let s:synid_cache[:] += [[byte], [synIDattr(synID(a:l, a:c, 0), 'name')]]
  endif
  return s:synid_cache[1][pos]
endfunction

if exists('g:VHTL_debugging')
  set debug=msg " show errors in indentexpr
  fu! SynAt(l,c)
    return s:SynAt(a:l,a:c)
  endfu
endif
fu! VHTL_debug(str)
  if exists('g:VHTL_debugging')
    echom a:str
  endif
endfu

let s:StateClass={}
fu! s:StateClass.new()
  let l:instance = copy(self)
  let l:instance.currLine = v:lnum
  let l:instance.prevLine = prevnonblank(v:lnum - 1)
  let l:instance.currSynstack = VHTL_SynSOL(l:instance.currLine)
  let l:instance.prevSynstack = VHTL_SynEOL(l:instance.prevLine)
  return l:instance
endfu

fu! s:StateClass.startsWithTemplateClose() dict
  return (getline(self.currSynstack)) =~# '^\s*`'
endfu

fu! s:StateClass.closedJsExpression() dict
  return VHTL_closesJsExpression(getline(self.prevLine))
endfu
fu! s:StateClass.closesJsExpression() dict
  return VHTL_closesJsExpression(getline(self.currLine))
endfu
fu! s:StateClass.openedJsExpression() dict
  return (VHTL_getBracketDepthChange(getline(self.prevLine)) > 0)
endfu
fu! s:StateClass.opensLitHtmlTemplate() dict
  return VHTL_opensTemplate(getline(self.currLine))
endfu
fu! s:StateClass.openedLitHtmlTemplate() dict
  return VHTL_opensTemplate(getline(self.prevLine))
endfu
fu! s:StateClass.closesLitHtmlTemplate() dict
  return VHTL_closesTemplate(getline(self.currLine))
endfu
fu! s:StateClass.closedLitHtmlTemplate() dict
  return VHTL_closesTemplate(getline(self.prevLine))
endfu

fu! s:StateClass.isInsideLitHtml() dict
  return VHTL_isSynstackInsideLitHtml(self.currSynstack)
endfu
fu! s:StateClass.wasInsideLitHtml() dict
  return VHTL_isSynstackInsideLitHtml(self.prevSynstack)
endfu
fu! s:StateClass.isInsideJsx() dict
  return IsSynstackInsideJsx(self.currSynstack)
endfu

fu! s:StateClass.wasHtml() dict
  return get(self.prevSynstack, -1) =~# '^html'
endfu
fu! s:StateClass.isHtml() dict
  return get(self.currSynstack, -1) =~# '^html'
endfu
fu! s:StateClass.wasJs() dict
  return get(self.prevSynstack, -1) =~# '^js'
endfu
fu! s:StateClass.isJs() dict
  return get(self.currSynstack, -1) =~# '^js'
endfu
fu! s:StateClass.wasCss() dict
  return get(self.prevSynstack, -1) =~# '^css'
endfu
fu! s:StateClass.isCss() dict
  return get(self.currSynstack, -1) =~# '^css'
endfu

fu! s:StateClass.toStr() dict
  return '{line ' . self.currLine . '}'
endfu

fu! s:SkipFuncJsTemplateBraces()
  " let l:char = getline(line('.'))[col('.')-1]
  let l:syntax = s:SynAt(line('.'), col('.'))
  if (l:syntax != 'jsTemplateBraces')
    echom 'SKIP YES because ' . l:syntax
    return 1
  endif
endfu

fu! s:SkipFuncLitHtmlRegion()
  " let l:char = getline(line('.'))[col('.')-1]
  let l:syntax = s:SynAt(line('.'), col('.'))
  if (l:syntax != 'litHtmlRegion')
    echom 'SKIP YES because ' . l:syntax
    return 1
  endif
endfu


" html tag, html template, or js expression on previous line
fu! s:StateClass.getIndentOfLastClose() dict
  let l:line = getline(self.prevLine)

  " The following regex converts a line to purely a list of closing words.
  " Pretty cool but not useful
  " echo split(getline(62), '.\{-}\ze\(}\|`\|<\/\w\+>\)')

  let l:anyCloserWord =  '}\|`\|<\/\w\+>'


  let l:index = 0
  let l:closeWords = []
  while v:true
    let [l:term, l:index, l:trash] = matchstrpos(l:line, l:anyCloserWord, l:index)
    if (l:index == -1)
      break
    else
      call add(l:closeWords, [l:term, l:index])
    endif
    let l:index += 1
  endwhile

  for l:item in reverse(l:closeWords)
    let [l:closeWord, l:col] = l:item
    let l:col += 1
    let l:syntax = s:SynAt(self.prevLine, l:col)
    call cursor(self.prevLine, l:col) " sets start point for searchpair()
    redraw
    if ("}" == l:closeWord && l:syntax == 'jsTemplateBraces')
      call searchpair('{', '', '}', 'b', 's:SkipFuncJsTemplateBraces()')
      echom 'JS BRACE BASE INDENT '
    elseif ("`" == l:closeWord && l:syntax == 'litHtmlRegion')
      call searchpair('html`', '', '\(html\)\@<!`', 'b', 's:SkipFuncLitHtmlRegion()')
      echom 'LIT HTML REGION BASE INDENT '
    elseif (l:syntax == 'htmlEndTag')
      let l:openWord = substitute(substitute(l:closeWord, '/', '', ''), '>', '', '')
      echom 'open word ' . l:openWord
      call searchpair(l:openWord, '', l:closeWord, 'b')
      echom 'HTML TAG REGION BASE INDENT '
    else
      echom "UNRECOGNIZED CLOSER SYNTAX: '" . l:syntax . "'"
      echom getline(line('.'))
    endif
    return indent(line('.')) " cursor was moved by searchpair()
  endfor
endfu

" com! MyTest exec "call s:StateClass.new().getIndentOfLastClose()"

" Dispatch to indent method for js/html (use custom rules for transitions
" between syntaxes)
fu! ComputeLitHtmlIndent()
  let s:synid_cache = [[],[]]

  let l:state = s:StateClass.new()

  " get most recent non-empty line
  let l:prev_lnum = prevnonblank(v:lnum - 1)

  let l:currLineSynstack = VHTL_SynSOL(v:lnum)
  let l:prevLineSynstack = VHTL_SynEOL(l:prev_lnum)

  if (!l:state.isInsideLitHtml() && !l:state.wasInsideLitHtml())
    call VHTL_debug('outside of litHtmlRegion')
    return eval(b:litHtmlOriginalIndentExpression)
  endif

  if (l:state.wasJs() && l:state.isJs())
    call VHTL_debug('default javascript indentation inside lit-html region')
    return eval(b:litHtmlOriginalIndentExpression)
  endif

  if (l:state.openedLitHtmlTemplate())
    call VHTL_debug('opened tagged template literal')
    return indent(l:prev_lnum) + &shiftwidth
  endif

  if (l:state.openedJsExpression())
    call VHTL_debug('opened js expression')
    return indent(l:prev_lnum) + &shiftwidth
  endif



  " lit, js, html, css

  " THIS ALGORITHM MIGHT ACTUALLY WORK
  " let l:indent_basis = previous matching js or template start, otherwise equal to previous line
  " let l:indent_delta = -1 for starting with closing tag, template, or expression

  let l:base_indent = l:state.getIndentOfLastClose()
  echom 'base indent ' . l:base_indent
  return l:base_indent


  " We add an extra dedent for closing } brackets, as long as the matching {
  " opener is not on the same line as an opening html`.
  "
  " This algorithm does not always work and must be rewritten (hopefully to
  " something simpler)
  "
  if (l:state.closesLitHtmlTemplate())
    call VHTL_debug('closed template')
    let l:result = indent(l:prev_lnum) - &shiftwidth
    if (VHTL_closesJsExpression(getline(l:prev_lnum)))
      call VHTL_debug('closed template at start and js expression')
      let l:result -= &shiftwidth
    endif
    return l:result
  endif
  if (l:state.openedLitHtmlTemplate())
    call VHTL_debug('opened template')
    return indent(l:prev_lnum) + &shiftwidth
  elseif (VHTL_closesTemplate(getline(l:prev_lnum)) && !VHTL_startsWithTemplateEnd(l:prev_lnum))
  " elseif (l:state.closedLitHtmlTemplate() && !l:state.closesLitHtmlTemplate())
    call VHTL_debug('closed template ' . l:adjustForClosingBracket)
    let l:result = indent(l:prev_lnum) - &shiftwidth + l:adjustForClosingBracket
    if (VHTL_closesTag(getline(v:lnum)))
      call VHTL_debug('closed template and tag ' . l:adjustForClosingBracket)
      let l:result -= &shiftwidth
    endif
    return l:result
  elseif (l:state.isHtml() && l:state.wasJs() && VHTL_closesJsExpression(getline(l:prev_lnum)))
    let l:result = indent(l:prev_lnum) - &shiftwidth
    call VHTL_debug('closes expression')
    if (VHTL_closesTag(getline(v:lnum)))
      let l:result -= &shiftwidth
      call VHTL_debug('closes expression and tag')
    endif
    return l:result
  elseif (l:isJs && l:wasJs)
    return eval(b:litHtmlOriginalIndentExpression)
  endif

  call VHTL_debug('defaulting to html indent')
  return HtmlIndent()
endfu
