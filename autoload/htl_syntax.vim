function! htl_syntax#amend(options)

  let l:css_templates = (exists('g:htl_css_templates') && g:htl_css_templates)
  let l:all_templates = (exists('g:htl_all_templates') && g:htl_all_templates)

  if exists('b:current_syntax')
    let s:current_syntax=b:current_syntax
    unlet b:current_syntax
  endif
  let g:main_syntax = 'java'
  syn include @HTMLSyntax syntax/html.vim
  unlet g:main_syntax
  " we let/unlet g:main_syntax as a hack to prevent syntax/html.vim from
  " re-sourcing syntax/javascript.vim. It also prevents syntax/html.vim from
  " ovoverridding syn-sync.
  if exists('s:current_syntax')
    let b:current_syntax=s:current_syntax
  endif

  if (l:css_templates)
    if exists('b:current_syntax')
      let s:current_syntax=b:current_syntax
      unlet b:current_syntax
    endif
    let g:main_syntax = 'not css'
    syn include @CSSSyntax syntax/css.vim
    unlet g:main_syntax
    " we let/unlet g:main_syntax to prevent syntax/css.vim from overridding
    " syn-sync.
    if exists('s:current_syntax')
      let b:current_syntax=s:current_syntax
    endif
  endif

  exec 'syntax region litHtmlRegion
        \ contains=@HTMLSyntax,' . (a:options.typescript ? 'typescriptInterpolation,typescriptTemplateSubstitution' : 'jsTemplateExpression') . '
        \ containedin=typescriptBlock
        \ start=' . (l:all_templates ? '+\(html\)\?`+' : '+\(\/\*\s*\)\?html\(\s*\*\/\)\?`+') . '
        \ skip=+\\`+
        \ end=+`+
        \ extend
        \ keepend
        \ '
  if (l:all_templates)
    hi def link litHtmlRegion String
  endif

  if (a:options.typescript)
    syn cluster typescriptExpression add=litHtmlRegion
    " syn cluster typescriptBlock      add=litHtmlRegion
  else
    syn cluster jsExpression         add=litHtmlRegion
  endif

  " allow js interpolation (${...}) inside html strings
  if (a:options.typescript)
    syntax region jsTemplateExpressionLitHtmlWrapper contained start=+${+ end=+}+ contains=typescriptInterpolation,typescriptTemplateSubstitution keepend containedin=htmlString,htmlComment
  else
    syntax region jsTemplateExpressionLitHtmlWrapper contained start=+${+ end=+}+ contains=jsTemplateExpression    keepend containedin=htmlString,htmlComment
  endif

  " prevent htmlValue from overextending because it will match on js expression
  if (a:options.typescript)
    syntax region jsTemplateExpressionAsHtmlValue start=+=[\t ]*${+ end=++ contains=typescriptInterpolation,typescriptTemplateSubstitution containedin=htmlTag
  else
    syntax region jsTemplateExpressionAsHtmlValue start=+=[\t ]*${+ end=++ contains=jsTemplateExpression    containedin=htmlTag
  endif

  if (l:css_templates)
    exec 'syntax region cssLiteral
          \ contains=@CSSSyntax,' . (a:options.typescript ? 'typescriptInterpolation,typescriptTemplateSubstitution' : 'jsTemplateExpression') . '
          \ start=+\(\/\*\s*\)\?css\(\s*\*\/\)\?`+
          \ skip=+\\`+
          \ end=+`+
          \ extend
          \ keepend
          \ '

    if (a:options.typescript)
      syn cluster typescriptExpression add=cssLiteral
   else
      syn cluster jsExpression         add=cssLiteral
    endif

    " allow js interpolation (${...}) inside css attributes
    if (a:options.typescript)
      syntax region cssTemplateExpressionWrapper contained start=+${+ end=+}+ contains=typescriptInterpolation,typescriptTemplateSubstitution keepend containedin=cssAttrRegion
    else
      syntax region cssTemplateExpressionWrapper contained start=+${+ end=+}+ contains=jsTemplateExpression    keepend containedin=cssAttrRegion
    endif
  endif
endfunction
