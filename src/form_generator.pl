/* Part of ACMS

Author:        Mike Elston
E-mail:        mike.elston@gmail.com

Copyright (c) 2024 Mike Elston

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

:- module(form_generator,
          [ search_form//2,
            search_selection/3,
            snake_to_spaced_camel_case/2,
            td//4
          ]).

/** <module> Form Generator

---++ Basic Concept

The database schema is used to automatically generate an application
web UI to create, view, update and delete data in specified tables.

For maximum generality the schema is assumed to consist of a set of
_|views|_ where a view is the result set of a stored query that presents
a limited perspective of the database to a user. Base tables are treated
as views.

---++ View Source Modules

To create a web UI for a particular view simply create a Prolog
application module named after the view. For example, if the view is
called _|aircraft|_, create the source module _|aircraft.pl|_. The
source module may be empty in which case a completely default-based UI
is generated.

The module is known as the _|view source module|_.

For any view with a view source module a
search form will be generated which displays a table of matches
corresponding to rows in a table. Clicking on a row in the match table
displays a form to edit or delete the table row. The search from also
provides a "new" row function (row insert).


---++ Menu Access

To gain access to a form via the menu system define a predicate as
follows:

user:menu_group_item(-Menu_Group, -Menu_Group_Item, -HX_Vals_Dict,-Target, -Permitted_Member_Types).

*|Examples|*

==
user:menu_group_item(data_maintenance, 'Member', [], view(member), ['ADMINISTRATOR', 'INSTRUCTOR']).
==

==
user:menu_group_item(reports, 'Member List', [], row_report(member, member_list), ['ADMINISTRATOR', 'INSTRUCTOR']).
==

==
user:menu_group_item(reports, 'Aircraft', #{},bespoke_report(aircraft_summary), ['ADMINISTRATOR', 'INSTRUCTOR']).
==

==
user:menu_group_item(bookings, 'Booking Sheet', #{reset_booking_date:true}, form(booking_sheet), ['ADMINISTRATOR', 'INSTRUCTOR']).
% Click on the menu item to set the booking date back to today
==

By convention such facts are defined in the associated view source
module.

---++ Customisation

The following predicates allow the default behaviour to be modified.
These predicates must be defined in the relevant view source module.

---++++ atomic_key_attribute(-Attribute_Name)
Attribute_Name is an atomic key for the view i.e. a unique key consisting of a single
database attribute.

*|Example|*
==
atomic_key_attribute(aircraft_registration).
==

This predicate is required only if there is no
attribute in the view named _|<View_Name>_ak|_ or _|<View_Name>_id|_.
Where there is such an attribute it must actually be a unique key.

---++++ grouped_booleans(-Position_Before_Attribute, -Boolean_Attribute_Names)
Realise a set of boolean values as check boxes rather than integer
input fields.

*|Example|*
==
grouped_booleans(comments, [paid_up, newsletter, social_events, fly_aways]).
==

---++++ initial_form_value(-Attribute_Name, -Value)
Value is the value to be displayed for field Attribute_Name when the
form is first displayed. Often used to initialise a date field to
the current date.

*|Example|*
==
initial_form_value(date_raised, Today) :-
    date_today(Today).
==

---++++ initial_search_restriction(-Alias, -Restriction)
Specify the selection restriction to determine the rows to be
displayed when the form is first displayed. Note that this overrides
the default behaviour where no search is performed when the form is
displayed.

*|Example|*
==
initial_search_restriction(_, true).   % Show all records
==


---++++ exclude_search_result_table_attribute(-Attribute_Name)
Do not show the specified attribute in the search results table. Often
used to prevent long fields e.g. comment feilds appearing in the
search results table.

*|Example|*
==
exclude_search_result_table_attribute(comments).
==

---++++ exclude_attribute(+Mode, -Attribute_Name)
Exclude the specified attribute from the creations or
view-update_delete form

*|Example|*
==
exclude_attribute(view_update_delete, last_sign_in).
==

---++++ html_type_override(+Attribute_Name, +Form_State, -HTML_Type, -HTML_Attributes)

Override the default HTML input field for the specified attribute.

*|Example 1 - Allowed values (combo-box)|*
==
html_type_override(record_status, _, 'select-one'(Choices), []) :-
    record_status_choices(Choices).
==

*|Example 2 - Searchable field (datalist)|*
==
html_type_override(member_id, _, datalist(member_id_datalist), []).
==
==
member_id_datalist(FS, Matches) :-
    aggregate_all(set(Match),
                  member_search_match(FS.member_id, Match),
                  Matches).
==

---++++ read_only_view.

Prevent UI from allowing view to be modified


@copyright Mike Elston
@license MIT
@author Mike Elston
*/

:- use_module(library(dcg/basics)).
:- use_module(library(http/htmx)).
:- use_module(library(http/html_write)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_client)).
:- use_module(library(http/json)).
:- use_module(library(pairs)).
:- use_module(library(http/http_host)).
:- use_module(library(error)).
:- use_module(library(solution_sequences)).
:- use_module(library(url)).

:- use_module(src(swisql), [sql_table_column/3,
                            sql_table_column/4]).

:- multifile
    user:menu_group_item/5.
:- dynamic
    user:menu_group_item/5.


:- http_handler(main(views/View_Form_Name), view_update_delete_form(View_Form_Name), []).

view_update_delete_form(View_Form_Name, _Request) :-
    FN = View_Form_Name,
    catch_with_backtrace(reply_htmx(\search_form(FN, #{'SEARCH_PURPOSE': view_update_delete})),
                         E,
                         reply_htmx(\sf_error_description(E))).


%!  search_form(+FN, +FS) // is det.
%
%   FS dict which must contain the field SEARCH_PURPOSE with the value
%   view_update_delete or generate_report

search_form(View_Name, FS) -->
    { Search_Purpose = FS.'SEARCH_PURPOSE',
      search_selection(View_Name, Search_Result_Attributes, Selection),
      sf_pairs_as_hx_vals(['VIEW_NAME'-View_Name, 'SEARCH_SELECTION'-Selection, 'SEARCH_RESULT_ATTRIBUTES'-Search_Result_Attributes, 'SEARCH_PURPOSE'-Search_Purpose], HX_Vals),
      snake_to_spaced_camel_case(View_Name, Title),
      (   read_only_view(View_Name)
      ->  Help_Text = 'Double-click a row to view'

      ;   Search_Purpose == view_update_delete
      ->  Help_Text = 'Double-click a row to view, update or delete'

      ;   Search_Purpose = generate_report(_)
      ->  Help_Text = 'Double-click a row to view report'
      )
    },
    html([h3([center(span(style('font-size:20px; text-align:center;'), Title)),
              span(class('htmx-indicator'),
                   [img([style('padding-left: 10px;'),
                         src('/icons/bars.svg')])])]),
          div([class('pure-form')],
              [input([type(search),
                      name('SEARCH_TARGET'),
                      autofocus,
                      placeholder('Begin Typing To Search ...'),
                      'hx-post'('/swif/search'),
                      'hx-trigger'('database_event from:body, input changed delay:500ms, search'),
                      'hx-target'('#search_results'),
                      'hx-indicator'('.htmx-indicator'),
                      'hx-vals'(HX_Vals)]),
               \create_new_record_button(Search_Purpose, Title, View_Name)]),

          table([class('pure-table pure-table-horizontal pure-table-striped')
                ],
                [thead(tr(\search_result_table_column_headers(Search_Result_Attributes))),
                 hr([]),
                 i(style('font-size:11px;'), Help_Text),
                 br([]),
                 tbody(id('search_results'), \initial_search(View_Name, Selection, Search_Result_Attributes, Search_Purpose))])]).

%!  create_new_record_button(+Search_Purpose, +Title, +View_Name) is det.

create_new_record_button(_, _, View_Name) -->
    {  read_only_view(View_Name),
       !
    },
    [].
create_new_record_button(view_update_delete, Title, View_Name) -->
    !,
    { format(atom(Create_Button_Label), 'Create New ~w', [Title])
    },
    html(\sf_modal_popup_button(create_new_record_button, Create_Button_Label, new_record_form_popup, sf_button_green, ['VIEW_NAME'-View_Name], [])).
create_new_record_button(_, _, _) -->
    [].



%!   read_only_view(+View_Name:atom).

read_only_view(View_Name) :-
    predicate_property(View_Name:read_only_view, visible),
    View_Name:read_only_view.


%! new_record_form_popup(+MPA) is det.

new_record_form_popup(MPA) -->
    { snake_to_spaced_camel_case(MPA.'VIEW_NAME', View_Name_Camelled),
      format(atom(H1), 'New ~w', [View_Name_Camelled]),
      View_Name = MPA.'VIEW_NAME',
      odbc_connection(C),
      findall(Attribute_Name,
              (   sql_table_column(C, View_Name, Attribute_Name),
                   \+ exclude_attribute(create, View_Name, Attribute_Name)
              ),
              Attribute_Names),
      (   grouped_booleans(View_Name, Position_Before_Attribute, Boolean_Attribute_Names)
      ->  phrase(attributes(Attribute_Names, Position_Before_Attribute, Boolean_Attribute_Names), Attributes)
      ;   Attributes = Attribute_Names
      ),
      initial_form_state(Attributes, View_Name, #{'VIEW_NAME': View_Name, 'ATTRIBUTES': Attributes, 'FORM_MODE': new_record}, FS1)
    },
    html([h1(H1),
          \(sf_form(new_record_form, new_record_form, FS1))]).


%! new_record_form(+FN, +FS) is det.

new_record_form(FN, FS) -->
    { sf_pairs_as_hx_vals(['VIEW_NAME'-FS.'VIEW_NAME'], HX_Vals)
    },
    html(\sf_form_htmx(FN,
                       [fieldset([class('pure-form pure-form-stacked'), style('border: none')],
                                 [\new_record_fields(FS.'ATTRIBUTES', FS.'VIEW_NAME', FN, FS, Required_Attributes, []),
                                  \sf_submit_button(insert, FS.'VIEW_NAME', FN, FS, Required_Attributes)])],
                       ['hx-vals'(HX_Vals)])).


%!  sf_submit_button(+Action, +View_Name, +FN, +FS, +Required_Attributes) is det.
%
%   @arg Action insert or update
%   @arg required_attributes list(atom) attributes for which the user must enter values

sf_submit_button(_, View_Name, _, _, _) -->
    { read_only_view(View_Name),
      !
    },
    [].
sf_submit_button(Action, _, FN, FS, Required_Attributes) -->
    {(   Required_Attributes == []
     ->  Submit_Button_Attributes = []

     ;   submit_button_required_fields_hyperscript(Required_Fields_Hyperscript),
         Submit_Button_Attributes = [style("transition: all 800ms ease-in"), '_'(Required_Fields_Hyperscript), disabled]
    )},
    html(\sf_form_action_button(Action, 'Submit', FN, FS, sf_button_green, Submit_Button_Attributes)).



%!  submit_button_required_fields_hyperscript(-Hyperscript:atom) is det.
%
%   From https://stackoverflow.com/questions/70200855/enable-submit-button-when-all-input-fields-are-valid-in-hyperscript

submit_button_required_fields_hyperscript(Hyperscript) :-
    Hyperscript = "on keyup from closest <form/> debounced at 150ms or input from closest <form/> or load from closest <form/> \c
    if (<[required]:invalid/>).length > 0 \c
    add @disabled \c
    put 'Check All Fields' into me \c
    then exit \c
    end \c
    remove @disabled \c
    put 'Submit' into me".


%!  initial_form_state(+Attributes, +View_Name:atom, +FS:dict, -FS:dict) is det.
%
%   @arg Attributes list of Attribute_Name and possibly one boolean_attributes/1

initial_form_state([], _, FS, FS).
initial_form_state([boolean_attributes(Boolean_Attribute_Names)|T], View_Name, FS0, FS2) :-
    !,
    initial_form_state(Boolean_Attribute_Names, View_Name, FS0, FS1),
    initial_form_state(T, View_Name, FS1, FS2).
initial_form_state([Attribute_Name|T], View_Name, FS0, FS2) :-
    (   initial_form_value(View_Name, Attribute_Name, Value)
    ->  FS1 = FS0.put([Attribute_Name=Value])

    ;   FS1 = FS0
    ),
    initial_form_state(T, View_Name, FS1, FS2).



%!  new_record_fields(+Attributes, +View_Name, +FN, +FS, -Required_Attributes, +Required_Attributes) is det.
%
%   @arg Attributes list of Attribute_Name and possibly one boolean_attributes/1
%   @arg Required_Attributes list(atom) Names of attributes which must not be NULL

new_record_fields([], _, _, _, RA, RA) -->
    [].
new_record_fields([Attribute_Name|T], View_Name, FN, FS, RA0, RA2) -->
    record_input_field(View_Name, Attribute_Name, FN, FS, RA0, RA1),
    new_record_fields(T, View_Name, FN, FS, RA1, RA2).


%!  record_input_field(+View_Name, +Attribute_Name, +FN, +FS, -Required_Attributes, +Required_Attributes) is det.

record_input_field(View_Name, boolean_attributes(Attribute_Names), FN, FS, RA, RA) -->
    { boolean_choices(Attribute_Names, Choices),
      (   read_only_view(View_Name)
      ->  HTML_Attributes = [readonly]
      ;   HTML_Attributes = []
      )
    },
    html([\sf_dbf(grouped_booleans, View_Name, '', checkbox(Choices), FN, FS, HTML_Attributes)]).

record_input_field(View_Name, Attribute_Name, _, _, RA, RA) -->
    { atomic_key_attribute(View_Name, Attribute_Name),
      !
    },
    [].

record_input_field(View_Name, Attribute_Name, FN, FS, RA0, RA1) -->
    { html_type(View_Name, Attribute_Name, FS, HTML_Type, HTML_Attributes_0),
      snake_to_spaced_camel_case(Attribute_Name, Label),
      (   required_input_attribute(View_Name, Attribute_Name)
      ->  HTML_Attributes_1 = [required, placeholder('Required')|HTML_Attributes_0],
          RA0 = [Attribute_Name|RA1]
      ;   HTML_Attributes_1 = HTML_Attributes_0,
          RA0 = RA1
      ),

      (   read_only_view(View_Name)
      ->  HTML_Attributes_2 = [readonly|HTML_Attributes_1]
      ;   HTML_Attributes_2 = HTML_Attributes_1
     )},
    html(p(\sf_dbf(Attribute_Name, View_Name, Label, HTML_Type, FN, FS, HTML_Attributes_2))).


%!  initial_search(+View_Name, +Selection, +Search_Result_Attributes, +Search_Purpose) is det.
%
%   Optionally pre-populate the search results table

initial_search(View_Name, Selection, Search_Result_Attributes, Search_Purpose) -->
    { Alias = v,
      initial_search_restriction(View_Name, Alias, Restriction),
      !,
      odbc_connection(C),
      findall(Row_Pairs,
              (   sql_select(Selection:Alias, Restriction, C),
                  search_2(Search_Result_Attributes, Selection, _, Row_Pairs)
              ),
              Rows)
    },
    html(\search_result_rows(Rows, View_Name, Search_Purpose)).

initial_search(_, _, _, _) -->
    [].


%! search_selection(+View_Name:atom, -Search_Result_Attributes, -Selection) is det.
%
%  @arg Search_Result_Attribute list(atom) Search results table column headers
%  @arg Selection term for sql_select/3

search_selection(View_Name, Attributes, Selection) :-
    odbc_connection(C),
    findall(Attribute_Name-_,
            (   sql_table_column(C, View_Name, Attribute_Name),
                \+ exclude_search_result_table_attribute(View_Name, Attribute_Name)
            ),
            Pairs),
    dict_pairs(Selection, View_Name, Pairs),
    pairs_keys(Pairs, Attributes).


%! search_result_table_column_headers(+Search_Result_Attributes) is det.

search_result_table_column_headers([]) -->
    [].
search_result_table_column_headers([Attribute_Name|T]) -->
    { snake_to_spaced_camel_case(Attribute_Name, Column_Name)
    },
    html([th([style('font-size:11px; text-align:center;')], Column_Name)]),
    search_result_table_column_headers(T).


:- http_handler(swif(search), search, []).

search(Request) :-
    catch_with_backtrace(search_0(Request),
                         E,
                         reply_htmx(\sf_error_description(E))).

search_0(Request) :-
    http_read_data(Request, Form_Pairs, []),
    sf_memberchk_hx_val('VIEW_NAME'=View_Name, Form_Pairs),
    memberchk('SEARCH_TARGET'=Search_Target_0, Form_Pairs),
    sf_memberchk_hx_val('SEARCH_SELECTION'=Selection, Form_Pairs),
    sf_memberchk_hx_val('SEARCH_RESULT_ATTRIBUTES'=Search_Result_Attributes, Form_Pairs),
    sf_memberchk_hx_val('SEARCH_PURPOSE'=Search_Purpose, Form_Pairs),
    (   integer(Search_Target_0)
    ->  atom_number(Search_Target_1, Search_Target_0)
    ;   Search_Target_1 = Search_Target_0
    ),
    search_row_limit(Limit),
    findall(Sort_Key-Row_Pairs, limit(Limit, search_1(Search_Target_1, Selection, View_Name, Search_Result_Attributes, Sort_Key, Row_Pairs)), Keyed_Rows),
    keysort(Keyed_Rows, Sorted_Keyed_Rows),   % Row sorting is ascending by table column
    pairs_values(Sorted_Keyed_Rows, Rows),
    reply_htmx(\search_result_rows(Rows, View_Name, Search_Purpose)).


%! search_row_limit(Limit:integer) is det.
%
%   Maximum number of rows search may return

search_row_limit(500).


%!  search_1(+Search_Target, +Selection, +View_Name, +Search_Result_Attributes, -Sort_Key, -Row_Pairs) is nondet.
%
%   @arg Search_Target atom the search string
%   @arg Selection dict values uninstantiated on call
%   @arg View_Name atom
%   @arg Search_Result_Attributes list of attribute names
%   @arg Sort_Key key determining the order the rows are displayed
%   @arg Row_Pairs pairs

search_1(Search_Target, Selection, View_Name, Search_Result_Attributes, Sort_Key, Row_Pairs) :-
    sf_trim(Search_Target, Trimmed_Search_Target),
    (   initial_search_restriction(View_Name, v, Initial_Restriction),
        Trimmed_Search_Target == ''
    ->  Restriction = Initial_Restriction

    ;   dict_pairs(Selection, View_Name, Query_Pairs),
        format(atom(ILIKE), '%~w%', [Trimmed_Search_Target]),
        search_restriction(Query_Pairs, View_Name, ILIKE, true, Restriction)
    ),
    odbc_connection(C),
    sql_select(Selection:v, Restriction, C),
    search_2(Search_Result_Attributes, Selection, Sort_Key, Row_Pairs).


%!  search_2(+Search_Result_Attributes, +Selection, -Sort_Key, -Row_Pairs) is det.

search_2([], _, [], []).
search_2([Attribute_Name|T1], Selection, [V|T2], [Attribute_Name-V|T3]) :-
    V = Selection.Attribute_Name,
    search_2(T1, Selection, T2, T3).


%!  search_restriction(+Query_Pairs, +View_Name, +ILIKE, +Restriction_Accum, -Restriction) is det.

search_restriction([], _, _, Restriction, Restriction).
search_restriction([Attribute_Name-_|T], View_Name, ILIKE, Accum, Restriction) :-
    odbc_connection(C),
    sql_table_column(C, View_Name, Attribute_Name, type(Type)),
    Type == text,
    !,
    search_restriction(T, View_Name, ILIKE, (v:Attribute_Name =~= ILIKE ; Accum), Restriction).
search_restriction([_|T], View_Name, ILIKE, Accum, Restriction) :-
    search_restriction(T, View_Name, ILIKE, Accum, Restriction).


%! search_result_rows(+Rows, +View_Name, +Search_Purpose) // is det.

search_result_rows([], _, _) -->
    [].
search_result_rows([Row|T], View_Name, Search_Purpose) -->
    { atomic_key_in_row(View_Name, Row, Atomic_Key),
      (   Search_Purpose == view_update_delete
      ->  phrase(sf_modal_popup_attributes(search, view_update_delete_popup, ['ATOMIC_KEY'-Atomic_Key]), Attributes, ['hx-trigger'(dblclick)])

      ;   Search_Purpose = generate_report(Report_ID)
      ->  format(atom(Atomic_Key_Atom), '~q', [Atomic_Key]),
          http_public_host(Request, _, _, []),
          memberchk(protocol(Protocol), Request),
          memberchk(host(Host), Request),
          memberchk(port(Port), Request),
          format(atom(Path), '/acms/reports/view/pdf/~w', [Report_ID]),
          parse_url(URL, [protocol(Protocol), host(Host), port(Port), path(Path), search([ak=Atomic_Key_Atom])]),
          format(atom(FUNCTION), 'window.open("~w", "_blank")', [URL]),
          Attributes = [ondblclick(FUNCTION)]

      ;   domain_error(search_purpose, Search_Purpose)
      )
    },
    html(tr(Attributes, [\search_result_row(Row, View_Name)])),
    search_result_rows(T, View_Name, Search_Purpose).


%!  atomic_key_in_row(+View_Name, +Row, -Atomic_Key) is det.
%
%   @arg View_Name atom
%   @arg Row list(pair)
%   @arg Atomic_Key atomic_key(View_Name, Attribute_Name, Key)

atomic_key_in_row(View_Name, Row, Atomic_Key) :-
    atomic_key_attribute(View_Name, Attribute_Name),
    memberchk(Attribute_Name-Key, Row),
    !,
    Atomic_Key = atomic_key(View_Name, Attribute_Name, Key).


%!  search_result_row(+Row_Pairs, +View_Name) is det.

search_result_row([], _) -->
    [].
search_result_row([Attribute_Name-V|T], View_Name) -->
    td(View_Name, Attribute_Name, V, td_style_attributes),
    search_result_row(T, View_Name).


%!  td_style_attributes(+View_Name, +Attribute_Name, +Value, +Default_Attributes, -Attributes)

td_style_attributes(_, _, _, Attributes, Attributes).


%!  td(+View_Name, +Attribute_Name, +Value, +Style_Pred) is det.
%
%   The style of the TD cell is determined by calling:
%   ==
%   <Style_Pred>(<Style_Pred Args>, +View_Name, +Attribute_Name, +Value, +Default_Attributes, -Attributes)
%   ==
%   Default_Attributes and Attributes area lists of :/2 terms e.g.
%   ['font-size':'11px', 'text-align': right]. Default_Attributes
%   can be inspected to assist with the determination of the required
%   attributes.
%
%   If the goal fails, the default attributes are used.
%
%   @arg View_Name, atom
%   @arg Attribute_Name atom
%   @arg Value internal value
%   @arg Style_Pred goal

:- meta_predicate
    td(+, +, +, :, ?, ?).

td(View_Name, Attribute_Name, Value, Style_Pred) -->
    { Value = N/D,
      !,
      odbc_connection(C),
      sql_table_column(C, View_Name, Attribute_Name, type(decimal(_, Scale))),
      Number is N/D,
      format(string(V), '~*f', [Scale, Number]),
      style(Style_Pred, View_Name, Attribute_Name, Value, ['font-size':'11px', 'text-align': right], Style)
    },
    html(td(style(Style), V)).

td(_, _, @(null), _) -->
    !,
    html(td('')).

td(View_Name, Attribute_Name, Value, Style_Pred) -->
    { Value == @(true),
      !,
      style(Style_Pred, View_Name, Attribute_Name, Value, ['font-size':'13px', 'text-align':center], Style)
    },
    html(td(style(Style), \['&#10003;'])).

td(View_Name, Attribute_Name, Value, Style_Pred) -->
    { Value == @(false),
      !,
      style(Style_Pred, View_Name, Attribute_Name, Value, ['font-size':'13px', 'text-align':center], Style)
    },
    html(td(style(Style), \['&#10007;'])).

td(View_Name, Attribute_Name, Value, Style_Pred) -->
    { Value = date(Y, M, D),
    !,
    format_time(string(V), '%x', date(Y, M, D)),
    style(Style_Pred, View_Name, Attribute_Name, Value, ['font-size':'11px', 'text-align':left], Style)
    },
    html(td(style(Style), V)).

td(View_Name, Attribute_Name, Timestamp, Style_Pred) -->
    { float(Timestamp),
      !,
      stamp_date_time(Timestamp, Date_Time, local),
      format_time(string(V), '%c', Date_Time),
      style(Style_Pred, View_Name, Attribute_Name, Timestamp, ['font-size':'11px', 'text-align':left], Style)
    },
    html(td(style(Style), V)).

td(View_Name, Attribute_Name, V, Style_Pred) -->
    { integer(V),
      !,
      style(Style_Pred, View_Name, Attribute_Name, V, ['font-size':'11px', 'text-align':right], Style)
    },
    html(td(style(Style), V)).


td(View_Name, Attribute_Name, V, Style_Pred) -->
    {  style(Style_Pred, View_Name, Attribute_Name, V, ['font-size':'11px', 'text-align':left], Style)
    },
    html(td(style(Style), V)).


%! style(+Style_Pred:goal, +View_Name:atom, +Attribute_Name:atom, +Value, +Default_Attributes:list(atom:atom), -Style:atom) is det.

:- meta_predicate
    style(:, +, +, +, +, -).

style(Module:Pred, View_Name, Attribute_Name, Value, Default_Attributes, Style) :-
    (   call(Module:Pred, View_Name, Attribute_Name, Value, Default_Attributes, Attributes)
    ->  true
    ;   Attributes = Default_Attributes
    ),
    phrase(semi_colon_separated(Attributes), Codes),
    string_codes(Style, Codes).


%! semi_colon_separated(+List) is det.

semi_colon_separated([]) -->
    [].
semi_colon_separated([A:B|T]) -->
    atom(A), `:`, atom(B), `;`,
    semi_colon_separated(T).


%!  view_update_delete_popup(+Modal_Popup_Attributes) // is det.
%
%   Popup form to view, update or delete the row double-clicked in the
%   search results table

view_update_delete_popup(MPA) -->
    { atomic_key(View_Name, Atomic_Key_Attribute, Key) = MPA.'ATOMIC_KEY',
      odbc_connection(C),
      findall(Attribute_Name-_,
              (   sql_table_column(C, View_Name, Attribute_Name),
                  \+ exclude_attribute(view_update_delete, View_Name, Attribute_Name)
              ),
              Selection_Pairs),
      pairs_keys(Selection_Pairs, VUD_Attributes),
      dict_pairs(Selection, View_Name, Selection_Pairs),
      (   sql_select(Selection:v, v:Atomic_Key_Attribute == Key, C)
      ->  dict_pairs(FS, _,  ['ATOMIC_KEY'-MPA.'ATOMIC_KEY', 'VUD_ATTRIBUTE_NAMES'-VUD_Attributes, 'FORM_MODE'-view_update_delete|Selection_Pairs])
      ;   existence_error(view, view(View_Name, ak(View_Name, Atomic_Key_Attribute, MPA.'ATOMIC_KEY')))
      )
    },
    html(\sf_form(view_update_delete_popup_1, view_update_delete_form, FS)).


%!  view_update_delete_popup_1(+FN, +FS) is det.

view_update_delete_popup_1(FN, FS) -->
    { atomic_key(View_Name, Atomic_Key_Attribute, Atomic_Key) = FS.'ATOMIC_KEY',
      Attribute_Names = FS.'VUD_ATTRIBUTE_NAMES',
      snake_to_spaced_camel_case(View_Name, View_Name_Camelled),

      (   grouped_booleans(View_Name, Position_Before_Attribute, Boolean_Attribute_Names)
      ->  phrase(attributes(Attribute_Names, Position_Before_Attribute, Boolean_Attribute_Names), Attributes)
      ;   Attributes = Attribute_Names
      ),
      sf_pairs_as_hx_vals(['VIEW_NAME'-View_Name], HX_Vals)
    },
    html(center(h2(View_Name_Camelled))),
    sf_form_htmx(FN,
                 [fieldset([class('pure-form pure-form-stacked'), style('border: none')],
                           [\view_update_delete_fields(Attributes, View_Name, Atomic_Key_Attribute, Atomic_Key, FN, FS, Required_Attributes, []),
                            \sf_submit_button(update, View_Name, FN, FS, Required_Attributes),
                            \delete_button(View_Name, FN, FS),
                            \sf_form_action_button(cancel, 'Cancel', FN, FS, sf_button_blue, [])])
                 ],
                 ['hx-vals'(HX_Vals)]).


%!  delete_button(+View_Name:atom, +FN, +FS) is det.

delete_button(View_Name, _, _) -->
    { read_only_view(View_Name),
      !
    },
    [].
delete_button(_, FN, FS) -->
    html(\sf_form_action_button(delete, 'Delete', FN, FS, sf_button_orange, [])).

%!  attributes(+Attribute_Names:list(atom),
%!             +Position_Before_Attribute:atom,
%!             +Boolean_Attribute_Names)
%!             is semidet.
%
%   Position the term boolean_attributes/1 in the list Attribute_Names
%   immediately before Position_Before_Attribute

attributes([], _, _) -->
    [].
attributes([Attribute_Name|T], Position_Before_Attribute, Boolean_Attribute_Names) -->
    { memberchk(Attribute_Name, Boolean_Attribute_Names),
      !
    },
    attributes(T, Position_Before_Attribute, Boolean_Attribute_Names).
attributes([Attribute_Name|T], Position_Before_Attribute, Boolean_Attribute_Names) -->
    { Attribute_Name == Position_Before_Attribute
    },
    !,
    [boolean_attributes(Boolean_Attribute_Names)],
    [Attribute_Name],
    attributes(T, Position_Before_Attribute, Boolean_Attribute_Names).
attributes([Attribute_Name|T], Position_Before_Attribute, Boolean_Attribute_Names) -->
    [Attribute_Name],
    attributes(T, Position_Before_Attribute, Boolean_Attribute_Names).



%!  view_update_delete_fields(+Attributes, +View_Name, +Atomic_Key_Attribute, +Atomic_Key, +FN, +FS, -Required_Attributes, +Required_Attributes) is det.
%
%   @arg Attributes list of atom and one or none boolean_attributes(Boolean_attributes)

view_update_delete_fields([], _, _, _, _, _, RA, RA) -->
    [].
view_update_delete_fields([Attribute|T], View_Name, Atomic_Key_Attribute, Atomic_Key, FN, FS, RA0, RA2) -->
    view_update_delete_field(View_Name, Attribute, Atomic_Key_Attribute, Atomic_Key, FN, FS, RA0, RA1),
    view_update_delete_fields(T, View_Name, Atomic_Key_Attribute, Atomic_Key, FN, FS, RA1, RA2).


%!  view_update_delete_field(+View_Name, +Attribute, +Atomic_Key_Attribute, +Atomic_Key, +FN, +FS, -Required_Attributes, +Required_Attributes) is det.

view_update_delete_field(View_Name, Atomic_Key_Attribute, Atomic_Key_Attribute, _, FN, FS, RA, RA) -->
    !,  % The atomic key - make read-only
    { snake_to_spaced_camel_case(Atomic_Key_Attribute, Label)
    },
    html([\sf_dbf(Atomic_Key_Attribute, View_Name, Label, _, FN, FS, [readonly])]).

view_update_delete_field(View_Name, Attribute_Name, _, _, FN, FS, RA0, RA1) -->
    record_input_field(View_Name, Attribute_Name, FN, FS, RA0, RA1).


%!  boolean_choices(+Attribute_Names, -Choices) is det.

boolean_choices([], []).
boolean_choices([Attribute_Name|T1], [Attribute_Name-Choice_Label|T2]) :-
    snake_to_spaced_camel_case(Attribute_Name, Choice_Label),
    boolean_choices(T1, T2).



%!  html_type(+View_Name, +Attribute_Name, +FS, -HTML_Type, -HTML_Attributes) is det.
%
%   Check for an override of the HTML_Type e.g. to uses textarea rather
%   than a text input field otherwise use the default input field for
%   the data (HTML_Type is left unbound)
%
%   @arg HTML_Type atom or free
%   @arg HTML_Attributes list

html_type(View_Name, Attribute_Name, FS, HTML_Type, HTML_Attributes) :-
    (   html_type_override(View_Name, Attribute_Name, FS, HTML_Type_0, HTML_Attributes_0)
    ->  sf_valid_dbf_html_type(HTML_Type_0),
        HTML_Type = HTML_Type_0,
        HTML_Attributes = HTML_Attributes_0

    ;   attribute_name_suggests_textarea(Attribute_Name)
    ->  HTML_Type = textarea,
        HTML_Attributes = [cols(50), rows(3)]

    ;   HTML_Attributes = []
    ).


%!  attribute_name_suggests_textarea(+Attribute_Name) is semidet.

attribute_name_suggests_textarea(Attribute_Name) :-
    sub_atom_suggests_textarea(Sub_Atom),
    sub_atom(Attribute_Name, _, _, 0, Sub_Atom),
    !.

%!  sub_atom_suggests_textarea(-Atom).

sub_atom_suggests_textarea(comments).
sub_atom_suggests_textarea(description).
sub_atom_suggests_textarea(notes).



%!  snake_to_spaced_camel_case(+Snake:atom, -Spaced_Camel:atom) is det.

snake_to_spaced_camel_case(Snake, Spaced_Camel) :-
   atomic_list_concat(Words, '_', Snake),
   capitalised_words(Words, Capitalised_Words),
   atomic_list_concat(Capitalised_Words, ' ', Spaced_Camel).


%! capitalised_words(+Words:list, -Capitalised_Words:list) is det.

capitalised_words([], []).
capitalised_words([Word|T1], [Acronym|T2]) :-
    acronym(Word, Acronym),
    !,
    capitalised_words(T1, T2).
capitalised_words([Word|T1], [Capitalised_Word|T2]) :-
    atom_codes(Word, [First_Code|Rest]),
    code_type(First_Code_UC, to_upper(First_Code)),
    atom_codes(Capitalised_Word, [First_Code_UC|Rest]),
    capitalised_words(T1, T2).


%!  acronym(+Word, -Acronym).

acronym(id, 'ID').
acronym(ak, 'AK').
acronym(caa, 'CAA').
acronym(gst, 'GST').
acronym(sql, 'SQL').
acronym(mauw, 'MAUW').


%!  required_input_attribute(+View_Name, +Attribute_Name) is nondet.
%
%   Required_Input_Attribute is a required field

required_input_attribute(View_Name, Attribute_Name) :-
    odbc_connection(C),
    sql_table_column(C, View_Name, Attribute_Name, nullable(0)).



%! sf_rule(?Rule_ID:atom, +Form_Name, +Trigger_Input_Name, +Form_State, +Inputs, -Outputs:pairs)

sf_rule(insert, new_record_form, _, FS, [insert-_], []) :-
    odbc_connection(C),
    sql_commit_or_rollback(insert_record(FS, C), C).

sf_rule(update, view_update_delete_form, _, FS, [update-_], []) :-
    odbc_connection(C),
    sql_commit_or_rollback(update_record(FS, C), C).

sf_rule(delete, view_update_delete_form, _, FS, [delete-_], []) :-
    odbc_connection(C),
    sql_commit_or_rollback(delete_record(FS, C), C).

sf_rule(cancel, view_update_delete_form, _, _, [cancel-_], []) :-
    sf_hx_trigger_header(#{close_modal_event:''}).


%!  insert_record(+FS, +Connection) is det.

insert_record(FS, C) :-
    View_Name = FS.'VIEW_NAME',
    view(View_Name, FS, C, View),
    atomic_key_attribute(View_Name, Atomic_Key_Attribute),
    sql_insert(View, Atomic_Key_Attribute, _, C),
    odbc_end_transaction(C, commit),
    sf_hx_trigger_header(#{database_event:'', close_modal_event:''}).


%!  update_record(+FS, +Connection) is det.

update_record(FS, C) :-
    View_Name = FS.'VIEW_NAME',
    view(View_Name, FS, C, View),
    atomic_key_attribute(View_Name, Atomic_Key_Attribute),
    sql_update(View:v, v:Atomic_Key_Attribute == FS.Atomic_Key_Attribute, C),
    odbc_end_transaction(C, commit),
    sf_hx_trigger_header(#{database_event:'', close_modal_event:''}).


%!  delete_record(+FS, +Connection) is det.

delete_record(FS, C) :-
    View_Name = FS.'VIEW_NAME',
    atomic_key_attribute(View_Name, Atomic_Key_Attribute),
    sql_delete(View_Name:v, v:Atomic_Key_Attribute == FS.Atomic_Key_Attribute, C),
    odbc_end_transaction(C, commit),
    sf_hx_trigger_header(#{database_event:'', close_modal_event:''}).


%!  view(+View_Name, +FS, +ODBC_Connection, -View:dict) is det.
%
%   View is a swisql table dict containing all the pairs in FS that are
%   attributes of View_Name

view(View_Name, FS, C, View) :-
    findall(Column_Name-Value,
            ( sql_table_column(C, View_Name, Column_Name, type(Type)),
              get_dict(Column_Name, FS, V),
              (   Type == text
              ->  sf_trim_to_null(V, Value)
              ;   Value = V
              )
            ),
            Columns),
    dict_pairs(View, View_Name, Columns).



%!  atomic_key_attribute(+View_Name:atom, ?Atomic_Key_Attribute:atom) is det.
%
%   Atomic_Key_Attribute is an atomic key for entity View_Name

atomic_key_attribute(View_Name, Atomic_Key_Attribute) :-
    must_be(atom, View_Name),
    (   current_module(View_Name)
    ->  true
    ;   existence_error(module, View_Name)
    ),
    (   predicate_property(View_Name:atomic_key_attribute(_), visible),
        View_Name:atomic_key_attribute(Attribute_Name)
    ->  Atomic_Key_Attribute = Attribute_Name

    ;   atomic_key_suffix(Suffix),
        format(atom(Attribute_Name), '~w_~w', [View_Name, Suffix]),
        odbc_connection(C),
        sql_table_column(C, View_Name, Attribute_Name)
    ->  Atomic_Key_Attribute = Attribute_Name

    ;   existence_error(atomic_key, View_Name)
    ).


%!  atomic_key_suffix(-Suffix:atom) is nondet.

atomic_key_suffix(ak).  % 'ak' = atomic key
atomic_key_suffix(id).


%!  grouped_booleans(+View_Name, -Position_Before_Attribute, -Boolean_Attribute_Names) is semidet.
%
%   Boolean_Attribute_Names is a list of attributes of entity View_Name
%   which are to be displayed as checkboxes. The checkboxes
%   are positioned on the form immediately before the attribute
%   Position_Before_Attribute.
%
%   @arg View_Name atom
%   @arg Position_Before_Attribute atom
%   @arg Boolean_Attribute_Names list(atom)

grouped_booleans(View_Name, Position_Before_Attribute, Boolean_Attribute_Names) :-
    must_be(atom, View_Name),
    must_be(var, Position_Before_Attribute),
    must_be(var, Boolean_Attribute_Names),
    (   current_module(View_Name)
    ->  true
    ;   existence_error(module, View_Name)
    ),
    predicate_property(View_Name:grouped_booleans(_, _), visible),
    View_Name:grouped_booleans(Position_Before_Attribute, Boolean_Attribute_Names).


%!  initial_form_value(+View_Name, +Attribute_Name, -Value) is semidet.
%
%   Value is the value to be displayed for field Attribute_Name when
%   the form is first displayed.
%
%   @arg View_Name atom
%   @arg Attribute_Name atom
%   @arg Value internal value (atom, integer, '/'/2, timestamp, date/3)

initial_form_value(View_Name, Attribute_Name, Value) :-
    must_be(atom, View_Name),
    must_be(atom, Attribute_Name),
    (   current_module(View_Name)
    ->  true
    ;   existence_error(module, View_Name)
    ),
    predicate_property(View_Name:initial_form_value(_, _), visible),
    View_Name:initial_form_value(Attribute_Name, Value).


%!  initial_search_restriction(+View_Name, +Alias, -Restriction) is semidet.
%
%   Specify the selection restriction to determine the rows to be
%   displayed when the form is displayed for entity View_Name.
%
%   A common requirement it to display all rows:
%   ==
%   initial_search_restriction(_, true)
%   ==
%
%   @arg View_Name atom
%   @arg Alias atom
%   @arg Restriction sql_select/3 restriction term

initial_search_restriction(View_Name, Alias, Restriction) :-
    must_be(atom, View_Name),
    must_be(atom, Alias),
    must_be(var, Restriction),
    (   current_module(View_Name)
    ->  true
    ;   existence_error(module, View_Name)
    ),
    predicate_property( View_Name:initial_search_restriction(_, _), visible),
    View_Name:initial_search_restriction(Alias, Restriction).


%!  exclude_search_result_table_attribute(+View_Name, +Attribute_Name) is semidet.
%
%   Do not show the specified attribute in the search results table
%
%   @arg View_Name atom
%   @arg Attribute_Name atom

exclude_search_result_table_attribute(View_Name, Attribute_Name) :-
    must_be(atom, View_Name),
    must_be(atom, Attribute_Name),
    (   current_module(View_Name)
    ->  true
    ;   existence_error(module, View_Name)
    ),
    predicate_property(View_Name:exclude_search_result_table_attribute(_), visible),
    View_Name:exclude_search_result_table_attribute(Attribute_Name).


%!  exclude_attribute(+Mode, +View_Name, +Attribute_Name) is semidet.
%
%   Exclude the specified attribute from the
%   create or view-update-delete form
%
%   @arg Mode
%   @arg View_Name atom
%   @arg Attribute_Name atom

exclude_attribute(Mode, View_Name, Attribute_Name) :-
    must_be(oneof([create, view_update_delete]), Mode),
    must_be(atom, View_Name),
    must_be(atom, Attribute_Name),
    (   current_module(View_Name)
    ->  true
    ;   existence_error(module, View_Name)
    ),
    predicate_property(View_Name:exclude_attribute(_, _), visible),
    View_Name:exclude_attribute(Mode, Attribute_Name).


%!  html_type_override(+View_Name, +Attribute_Name, +FS, -HTML_Type, -HTML_Attributes) is semidet.
%
%   @arg View_Name atom
%   @arg Attribute_Name atom
%   @arg FS Form state dict
%   @arg HTML_Type atom
%   @arg HTML_Attributes list

html_type_override(View_Name, Attribute_Name, FS, HTML_Type, HTML_Attributes) :-
    must_be(atom, View_Name),
    must_be(atom, Attribute_Name),
    must_be(dict, FS),
    must_be(var, HTML_Type),
    must_be(var, HTML_Attributes),
    (   current_module(View_Name)
    ->  true
    ;   existence_error(module, View_Name)
    ),
    predicate_property(View_Name:html_type_override(_, _, _, _), visible),
    View_Name:html_type_override(Attribute_Name, FS, HTML_Type, HTML_Attributes).
