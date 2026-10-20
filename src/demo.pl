/* Part of swipl_htmx_demo

Author:        Mike Elston
E-mail:        mike.elston@gmail.com

MIT License

Copyright (c) 2026 Mike Elston

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

:- module(demo,
          [
          ]).

/** <module> SWI Prolog HTMX Demo

@copyright Mike Elston
@license MIT
@author Mike Elston
*/

:- use_module(library(http/http_server)).
:- use_module(library(http/html_head)).
:- use_module(library(http/html_write)).
:- use_module(library(http/htmx)).

:- multifile http:location/3.
:- dynamic   http:location/3.

http:location(main, root(demo), []).

:- initialization(http_server(http_dispatch, [port(4500)]), program).


%!  home(+Request) is det.
%
%   Entry point i.e. the home page

:- http_handler(root(demo), home, []).


home(_Request) :-
     catch_with_backtrace(reply_html_page(
                              [ title('Demo'),
                                meta('name="viewport" content="width=device-width, initial-scale=1"'),    % Make it look nice on a small screen
                                \pure_style,
                                script('https://unpkg.com/htmx.org@1.9.0', []),  % 2.0.0 caused problems with hx-disabled-elt
                                script('https://unpkg.com/hyperscript.org@0.9.13', [])
                              ],
                              [ \html_requires(css('swif.css')),
                                \search_form]),
                          E,
                          reply_html_page(title('Error'), \sf_error_description(E))).

%!   search_form

search_form -->
     html(\search_form(invoice, #{'SEARCH_PURPOSE': view_update_delete})).


%!  pure_style is det.

pure_style -->
   html(link([rel('stylesheet'),
              href('https://cdn.jsdelivr.net/npm/purecss@3.0.0/build/pure-min.css'),
              integrity('sha384-X38yfunGUhNzHpBaEBsWLO+A0HDYOQi8ufWDkZ0k9e0eXz/tH3II7uKZ9msv++Ls'),
              crossorigin(anonymous)])).











