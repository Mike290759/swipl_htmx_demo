:- set_prolog_flag(source_search_working_directory, true).

:- portray_text(true).    % Enable portray of strings

:- multifile user:file_search_path/2.
:- dynamic user:file_search_path/2.

user:file_search_path(src, './src').
user:file_search_path(css, css).
user:file_search_path(icons, icons).

:- use_module(src(swif)).
:- use_module(src(swisql)).
:- use_module(src(reports)).
:- use_module(src(form_generator)).
:- use_module(src(invoice)).
:- use_module(src(demo)).


%!  gst_rate(-GST_Rate) is det.
%
%   @arg GST_Rate expression e.g. 0.15 means 15%

gst_rate(15/100).
