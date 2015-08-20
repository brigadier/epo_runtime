-module(epo_gettext).

-export([gettext/2, gettext/3, ngettext/4, ngettext/5, pgettext/3, pgettext/4, npgettext/5, npgettext/6, to_integer/1, to_boolean/1]).
-export([parse_transform/2]).

-record(porec2, {msgstr, msgstr_n = {}, n_max}).


parse_transform(Forms, Options) ->
	case lists:keyfind(gettext, 1, Options) of

		{_, Module} when is_atom(Module) -> parse_forms(Forms, Module);
		_ -> exit("Must compile with {gettext, gettext_po_module_name}\n")
	end.


parse_forms(Forms, Module) when is_list(Forms) ->
	[parse_forms(F, Module) || F <- Forms];


parse_forms({call, _N1, {var, _N2, '__'}, [Var]} = _Form, _Module) ->
	Var;
parse_forms({call, N1, {var, N2, '_'}, Params} = Form, Module) when is_list(Params) ->
	L = length(Params),
	case L of
		1 -> {call, N1, {remote, N2, {atom, N2, Module}, {atom, N2, gettext}}, [{atom, N2, Module} | Params]};
		2 -> {call, N1, {remote, N2, {atom, N2, Module}, {atom, N2, gettext}}, [{atom, N2, Module} | Params]};
		3 -> {call, N1, {remote, N2, {atom, N2, Module}, {atom, N2, ngettext}}, [{atom, N2, Module} | Params]};
		4 -> {call, N1, {remote, N2, {atom, N2, Module}, {atom, N2, ngettext}}, [{atom, N2, Module} | Params]};
		_ -> Form
	end;

parse_forms(Forms, Module) when is_tuple(Forms) ->
	list_to_tuple(parse_forms(tuple_to_list(Forms), Module));

parse_forms(Form, _Module) -> Form.


gettext(Mod, Literal) ->
	gettext(Mod, Literal, undefined).
gettext(Mod, {Context, Literal}, Locale) ->
	pgettext_(Mod, Context, Literal, Locale);
gettext(Mod, Literal, Locale) ->
	pgettext_(Mod, undefined, Literal, Locale).


pgettext(Mod, Context, Literal) ->
	pgettext(Mod, Context, Literal, undefined).

pgettext(Mod, Context, Literal, Locale) ->
	pgettext_(Mod, Context, Literal, Locale).


ngettext(Mod, Literal, Plural, N) ->
	ngettext(Mod, Literal, Plural, N, undefined).

ngettext(Mod, {Context, Literal}, Plural, N, Locale) ->
	npgettext_(Mod, Context, Literal, Plural, N, Locale);
ngettext(Mod, Literal, Plural, N, Locale) ->
	npgettext_(Mod, undefined, Literal, Plural, N, Locale).


npgettext(Mod, Context, Literal, Plural, N) ->
	npgettext(Mod, Context, Literal, Plural, N, undefined).

npgettext(Mod, Context, Literal, Plural, N, Locale) ->
	npgettext_(Mod, Context, Literal, Plural, N, Locale).

pgettext_(Mod, Context, Literal, Locale) when is_list(Literal) ->
	binary_to_list(pgettext_(Mod, Context, list_to_binary(Literal), Locale));

pgettext_(Mod, Context_, Literal, Locale_) ->
	Locale = locale(Locale_),
	Context = to_bin(Context_),
	case lookup(Mod, {Context, Literal}, Locale) of
		undefined -> Literal;
		#porec2{msgstr = undefined, msgstr_n = MsgStrN} -> element(1, MsgStrN);
		#porec2{msgstr = MsgStr} -> MsgStr
	end.


npgettext_(Mod, Context, Literal, Plural, N, Locale) when is_list(Literal) ->
	binary_to_list(npgettext_(Mod, Context, list_to_binary(Literal), Plural, N, Locale));
npgettext_(Mod, Context_, Literal, Plural_, N, Locale_) ->
	Locale = locale(Locale_),
	Context = to_bin(Context_),
	Plural = to_bin(Plural_),
	case lookup(Mod, {Context, Literal}, Locale) of
		undefined when N > 1 -> Plural;
		undefined -> Literal;
		PoRec -> plural(Mod, PoRec, Plural, N, Locale)
	end.

plural(Mod, #porec2{msgstr = MsgStr, msgstr_n = MsgStrN, n_max = NMax}, Plural, N, Locale) ->
	Idx = Mod:get_idx(N, Locale) + 1,
	if
		NMax >= Idx -> element(Idx, MsgStrN);
		NMax > 1 -> element(1, MsgStrN);
		N > 1 -> Plural;
		true -> MsgStr
	end.


to_bin(B) when is_binary(B) -> B;
to_bin(S) when is_list(S) -> list_to_binary(S);
to_bin(undefined) -> undefined;
to_bin(A) when is_atom(A) -> atom_to_binary(A, latin1).


locale(undefined) ->
	case erlang:get(locale) of
		undefined -> undefined;
		Locale -> locale(Locale)
	end;
locale(L) -> to_bin(L).

lookup(_Mod, _, undefined) -> undefined;
lookup(Mod, {undefined, Key}, Locale) ->
	lookup(Mod, Key, Locale);
lookup(Mod, Key, Locale) ->
	case Mod:get_record(Key, Locale) of
		undefined  ->
			case Locale of
				<<Locale2:2/binary, $_, _/binary>> -> lookup(Mod, Key, Locale2);
				_ -> undefined
			end;
		Result  -> Result
	end.


to_integer(true) -> to_integer(1);
to_integer(false) -> to_integer(0);
to_integer(N) when is_integer(N) -> N.

to_boolean(true) -> true;
to_boolean(false) -> false;
to_boolean(N) when N > 0 -> to_boolean(true);
to_boolean(N) when N == 0 -> to_boolean(false).