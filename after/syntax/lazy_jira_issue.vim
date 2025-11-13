" after/syntax/lazy_jira_issue.vim

syntax match JiraTitle       /^# .*/
syntax match JiraSection     /^■ .*/
syntax match JiraMetaKey     /^\s*•\s\+\w\+:/ 
syntax match JiraUrl         /https:\/\/[A-Za-z0-9._\/\-]\+/

syntax match JiraCommentAuthor /^\s*•\s\+\S.\{-}\s\+—/
syntax match JiraCommentDate /—\s\+\d\d\d\d-\d\d-\d\d \d\d:\d\d/

highlight link JiraTitle        Title
highlight link JiraSection      Function
highlight link JiraMetaKey      Keyword
highlight link JiraUrl          Underlined
highlight link JiraCommentAuthor Identifier
highlight link JiraCommentDate  Comment
