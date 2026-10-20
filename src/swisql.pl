/*
 * Dummy module to simulate an ODBC database
 */

:- module(swisql,
          [ odbc_connection/1,
            sql_atom_to_numeric/2,
            sql_delete/3,
            sql_insert/4,
            sql_numeric/1,
            sql_odbc_connection/2,
            sql_select/3,
            sql_commit_or_rollback/2,
            sql_table_column/3,
            sql_table_column/4,
            sql_update/3
          ]).

:- use_module(library(dcg/basics), [atom//1, digits//1, integer//1]).

odbc_connection(_).

:- op(750,yfx,user:(#)).
:- op(750,yfx,user:(*==)).
:- op(750,yfx,user:(=*=)).
:- op(750,yfx,user:(*==)).
:- op(700, xfx, user:(=~=)).
:- op(700, xfx, user:(in)).   % Same as clp(fd)

%!  sql_atom_to_numeric(+Atom:atom, -Number) is semidet.
%
%   If Atom is the text of an integer, Number is the corresponding
%   integer otherwise if Atom is the text of a decimal number, i.e.
%   one with a decimal point, Number is the corresponding '/'/2 term
%
%   Fails if Atom is not one of the two formats described here
%
%   @arg Number integer or '/'/2 e.g. 1234/100 for 12.34

sql_atom_to_numeric(Atom, Number) :-
    atom_codes(Atom, Codes),
    codes_number(Codes, Number).


%!  codes_number(+Codes, -Integer) is semidet.

codes_number(Codes, Integer) :-
    phrase(integer(I), Codes),
    !,
    Integer = I.
codes_number(Codes, Ratio) :-
    phrase((whole_digits(W), digits(Decimal_Digits)), Codes),
    phrase(integer(D), Decimal_Digits),
    length(Decimal_Digits, NDP),
    Denominator is 10 ** NDP,
    (   W < 0
    ->  Sign = -1
    ;   Sign = +1
    ),
    Numerator is  Sign * ((abs(W) * Denominator) + D),
    Ratio = Numerator / Denominator.


%!  whole_digits(Whole:integer) is det.

whole_digits(0) -->
    `.`,
    !.
whole_digits(W) -->
    integer(W), `.`.


%!  sql_numeric(+N) is semidet.
%
%   Succeeds if N is a swisql numeric value

sql_numeric(N) :-
    ground(N),
    N = A / B,
    integer(A),
    integer(B).


sql_select(Invoice:v,(v:notes=~='%%';v:member_id=~='%%';v:debtor_name=~='%%';v:debtor_email=~='%%';v:debtor_address_line_4=~='%%';v:debtor_address_line_3=~='%%';v:debtor_address_line_2=~='%%';v:debtor_address_line_1=~='%%';true),_) :-
    invoice(_, Invoice).

sql_select(Invoice:v, v:invoice_id==ID,_) :-
    @@@(id(ID)),
    invoice(ID, Invoice).


invoice(1, invoice{debtor_address_line_1:'19 Avion Tce',debtor_address_line_2:'Silverstream',debtor_address_line_3:'Upper Hutt 7865',debtor_address_line_4: @(null),debtor_email:'mike.elston@gmail.com',debtor_name:'Mike Elston',due_date:date(2024,8,20),gst:5130/100,invoice_date:date(2024,7,29),invoice_id:1,member_id:'ELSTONM',notes: @(null),total:39330/100,total_excl_gst:34200/100}).

invoice(2, invoice{debtor_address_line_1:'20 Egg St',debtor_address_line_2:'Petone',debtor_address_line_3:'Lower Hut 9010',debtor_address_line_4: @(null),debtor_email:'elon.musk@gmail.com',debtor_name:'Elon Musk',due_date:date(2026,9,21),gst:51300/100,invoice_date:date(2026,8,29),invoice_id:2,member_id:'ELSTONM',notes: @(null),total:393300/100,total_excl_gst:342000/100}).


sql_delete(_,_,_).
sql_insert(_, _, _, _).
sql_commit_or_rollback(_, _).
sql_update(_, _, _).
sql_odbc_connection(_, _).

sql_table_column(A, B, C) :-
    bagof(Facet,
          sql_table_column(A, B, C, Facet),
          _).

sql_table_column(acms,invoice,member_id,table_qualifier(acms)).
sql_table_column(acms,invoice,member_id,table_owner(public)).
sql_table_column(acms,invoice,member_id,table_name(invoice)).
sql_table_column(acms,invoice,member_id,data_type(-1)).
sql_table_column(acms,invoice,member_id,type_name(text)).
sql_table_column(acms,invoice,member_id,precision(8190)).
sql_table_column(acms,invoice,member_id,length(8190)).
sql_table_column(acms,invoice,member_id,nullable(0)).
sql_table_column(acms,invoice,member_id,remarks('')).
sql_table_column(acms,invoice,member_id,type(text)).
sql_table_column(acms,invoice,invoice_date,table_qualifier(acms)).
sql_table_column(acms,invoice,invoice_date,table_owner(public)).
sql_table_column(acms,invoice,invoice_date,table_name(invoice)).
sql_table_column(acms,invoice,invoice_date,data_type(91)).
sql_table_column(acms,invoice,invoice_date,type_name(date)).
sql_table_column(acms,invoice,invoice_date,precision(10)).
sql_table_column(acms,invoice,invoice_date,length(6)).
sql_table_column(acms,invoice,invoice_date,nullable(1)).
sql_table_column(acms,invoice,invoice_date,remarks('')).
sql_table_column(acms,invoice,invoice_date,type(date)).
sql_table_column(acms,invoice,due_date,table_qualifier(acms)).
sql_table_column(acms,invoice,due_date,table_owner(public)).
sql_table_column(acms,invoice,due_date,table_name(invoice)).
sql_table_column(acms,invoice,due_date,data_type(91)).
sql_table_column(acms,invoice,due_date,type_name(date)).
sql_table_column(acms,invoice,due_date,precision(10)).
sql_table_column(acms,invoice,due_date,length(6)).
sql_table_column(acms,invoice,due_date,nullable(1)).
sql_table_column(acms,invoice,due_date,remarks('')).
sql_table_column(acms,invoice,due_date,type(date)).
sql_table_column(acms,invoice,debtor_name,table_qualifier(acms)).
sql_table_column(acms,invoice,debtor_name,table_owner(public)).
sql_table_column(acms,invoice,debtor_name,table_name(invoice)).
sql_table_column(acms,invoice,debtor_name,data_type(-1)).
sql_table_column(acms,invoice,debtor_name,type_name(text)).
sql_table_column(acms,invoice,debtor_name,precision(8190)).
sql_table_column(acms,invoice,debtor_name,length(8190)).
sql_table_column(acms,invoice,debtor_name,nullable(1)).
sql_table_column(acms,invoice,debtor_name,remarks('')).
sql_table_column(acms,invoice,debtor_name,type(text)).
sql_table_column(acms,invoice,debtor_address_line_1,table_qualifier(acms)).
sql_table_column(acms,invoice,debtor_address_line_1,table_owner(public)).
sql_table_column(acms,invoice,debtor_address_line_1,table_name(invoice)).
sql_table_column(acms,invoice,debtor_address_line_1,data_type(-1)).
sql_table_column(acms,invoice,debtor_address_line_1,type_name(text)).
sql_table_column(acms,invoice,debtor_address_line_1,precision(8190)).
sql_table_column(acms,invoice,debtor_address_line_1,length(8190)).
sql_table_column(acms,invoice,debtor_address_line_1,nullable(1)).
sql_table_column(acms,invoice,debtor_address_line_1,remarks('')).
sql_table_column(acms,invoice,debtor_address_line_1,type(text)).
sql_table_column(acms,invoice,debtor_address_line_2,table_qualifier(acms)).
sql_table_column(acms,invoice,debtor_address_line_2,table_owner(public)).
sql_table_column(acms,invoice,debtor_address_line_2,table_name(invoice)).
sql_table_column(acms,invoice,debtor_address_line_2,data_type(-1)).
sql_table_column(acms,invoice,debtor_address_line_2,type_name(text)).
sql_table_column(acms,invoice,debtor_address_line_2,precision(8190)).
sql_table_column(acms,invoice,debtor_address_line_2,length(8190)).
sql_table_column(acms,invoice,debtor_address_line_2,nullable(1)).
sql_table_column(acms,invoice,debtor_address_line_2,remarks('')).
sql_table_column(acms,invoice,debtor_address_line_2,type(text)).
sql_table_column(acms,invoice,debtor_address_line_3,table_qualifier(acms)).
sql_table_column(acms,invoice,debtor_address_line_3,table_owner(public)).
sql_table_column(acms,invoice,debtor_address_line_3,table_name(invoice)).
sql_table_column(acms,invoice,debtor_address_line_3,data_type(-1)).
sql_table_column(acms,invoice,debtor_address_line_3,type_name(text)).
sql_table_column(acms,invoice,debtor_address_line_3,precision(8190)).
sql_table_column(acms,invoice,debtor_address_line_3,length(8190)).
sql_table_column(acms,invoice,debtor_address_line_3,nullable(1)).
sql_table_column(acms,invoice,debtor_address_line_3,remarks('')).
sql_table_column(acms,invoice,debtor_address_line_3,type(text)).
sql_table_column(acms,invoice,debtor_address_line_4,table_qualifier(acms)).
sql_table_column(acms,invoice,debtor_address_line_4,table_owner(public)).
sql_table_column(acms,invoice,debtor_address_line_4,table_name(invoice)).
sql_table_column(acms,invoice,debtor_address_line_4,data_type(-1)).
sql_table_column(acms,invoice,debtor_address_line_4,type_name(text)).
sql_table_column(acms,invoice,debtor_address_line_4,precision(8190)).
sql_table_column(acms,invoice,debtor_address_line_4,length(8190)).
sql_table_column(acms,invoice,debtor_address_line_4,nullable(1)).
sql_table_column(acms,invoice,debtor_address_line_4,remarks('')).
sql_table_column(acms,invoice,debtor_address_line_4,type(text)).
sql_table_column(acms,invoice,debtor_email,table_qualifier(acms)).
sql_table_column(acms,invoice,debtor_email,table_owner(public)).
sql_table_column(acms,invoice,debtor_email,table_name(invoice)).
sql_table_column(acms,invoice,debtor_email,data_type(-1)).
sql_table_column(acms,invoice,debtor_email,type_name(text)).
sql_table_column(acms,invoice,debtor_email,precision(8190)).
sql_table_column(acms,invoice,debtor_email,length(8190)).
sql_table_column(acms,invoice,debtor_email,nullable(1)).
sql_table_column(acms,invoice,debtor_email,remarks('')).
sql_table_column(acms,invoice,debtor_email,type(text)).
sql_table_column(acms,invoice,notes,table_qualifier(acms)).
sql_table_column(acms,invoice,notes,table_owner(public)).
sql_table_column(acms,invoice,notes,table_name(invoice)).
sql_table_column(acms,invoice,notes,data_type(-1)).
sql_table_column(acms,invoice,notes,type_name(text)).
sql_table_column(acms,invoice,notes,precision(8190)).
sql_table_column(acms,invoice,notes,length(8190)).
sql_table_column(acms,invoice,notes,nullable(1)).
sql_table_column(acms,invoice,notes,remarks('')).
sql_table_column(acms,invoice,notes,type(text)).
sql_table_column(acms,invoice,total_excl_gst,table_qualifier(acms)).
sql_table_column(acms,invoice,total_excl_gst,table_owner(public)).
sql_table_column(acms,invoice,total_excl_gst,table_name(invoice)).
sql_table_column(acms,invoice,total_excl_gst,data_type(2)).
sql_table_column(acms,invoice,total_excl_gst,type_name(numeric)).
sql_table_column(acms,invoice,total_excl_gst,precision(8)).
sql_table_column(acms,invoice,total_excl_gst,length(10)).
sql_table_column(acms,invoice,total_excl_gst,scale(2)).
sql_table_column(acms,invoice,total_excl_gst,radix(10)).
sql_table_column(acms,invoice,total_excl_gst,nullable(1)).
sql_table_column(acms,invoice,total_excl_gst,remarks('')).
sql_table_column(acms,invoice,total_excl_gst,type(decimal(8,2))).
sql_table_column(acms,invoice,gst,table_qualifier(acms)).
sql_table_column(acms,invoice,gst,table_owner(public)).
sql_table_column(acms,invoice,gst,table_name(invoice)).
sql_table_column(acms,invoice,gst,data_type(2)).
sql_table_column(acms,invoice,gst,type_name(numeric)).
sql_table_column(acms,invoice,gst,precision(8)).
sql_table_column(acms,invoice,gst,length(10)).
sql_table_column(acms,invoice,gst,scale(2)).
sql_table_column(acms,invoice,gst,radix(10)).
sql_table_column(acms,invoice,gst,nullable(1)).
sql_table_column(acms,invoice,gst,remarks('')).
sql_table_column(acms,invoice,gst,type(decimal(8,2))).
sql_table_column(acms,invoice,total,table_qualifier(acms)).
sql_table_column(acms,invoice,total,table_owner(public)).
sql_table_column(acms,invoice,total,table_name(invoice)).
sql_table_column(acms,invoice,total,data_type(2)).
sql_table_column(acms,invoice,total,type_name(numeric)).
sql_table_column(acms,invoice,total,precision(8)).
sql_table_column(acms,invoice,total,length(10)).
sql_table_column(acms,invoice,total,scale(2)).
sql_table_column(acms,invoice,total,radix(10)).
sql_table_column(acms,invoice,total,nullable(1)).
sql_table_column(acms,invoice,total,remarks('')).
sql_table_column(acms,invoice,total,type(decimal(8,2))).
sql_table_column(acms,invoice,invoice_id,table_qualifier(acms)).
sql_table_column(acms,invoice,invoice_id,table_owner(public)).
sql_table_column(acms,invoice,invoice_id,table_name(invoice)).
sql_table_column(acms,invoice,invoice_id,data_type(4)).
sql_table_column(acms,invoice,invoice_id,type_name(int4)).
sql_table_column(acms,invoice,invoice_id,precision(10)).
sql_table_column(acms,invoice,invoice_id,length(4)).
sql_table_column(acms,invoice,invoice_id,scale(0)).
sql_table_column(acms,invoice,invoice_id,radix(10)).
sql_table_column(acms,invoice,invoice_id,nullable(0)).
sql_table_column(acms,invoice,invoice_id,remarks('')).
sql_table_column(acms,invoice,invoice_id,type(int4)).


























