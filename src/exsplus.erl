%% @author Kenji Rikitake <kenji.rikitake@acm.org>
%% @copyright 2014 Kenji Rikitake
%% @doc Xorshift128plus for Erlang
%% @end
%% (MIT License)
%%
%% Copyright (c) 2014 Kenji Rikitake. All rights reserved.
%%
%% Permission is hereby granted, free of charge, to any person obtaining a copy of
%% this software and associated documentation files (the "Software"), to deal in
%% the Software without restriction, including without limitation the rights to
%% use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
%% of the Software, and to permit persons to whom the Software is furnished to do
%% so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included in all
%% copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
%% SOFTWARE.
%%

-module(exsplus).

-export([
     next/1,
     seed0/0,
     seed/0,
     seed/1,
     seed/3,
     uniform/0,
     uniform/1,
     uniform_s/1,
     uniform_s/2
 ]).

-export_type([
        state/0,
        uint64/0
    ]).

%% @type uint64(). 64bit unsigned integer type.

-type uint64() :: 0..16#ffffffffffffffff.

-record(state, {s0 :: uint64(), s1 :: uint64()}).

%% @type state(). Internal state data type for exsplus.
%% Internally represented as the record <code>#state{}</code>,
%% of the 128bit seed.

-opaque state() :: #state{}.

-define(UINT64MASK, 16#ffffffffffffffff).

%% @doc Advance xorshift128plus state for one step.
%% and generate 64bit unsigned integer from
%% the xorshift128plus internal state.

-spec next(state()) -> {uint64(), state()}.

next(R) ->
    S1 = R#state.s0,
    S0 = R#state.s1,
    S11 = (S1 bxor (S1 bsl 23)) band ?UINT64MASK,
    S12 = S11 bxor S0 bxor (S11 bsr 17) bxor (S0 bsr 26),
    {(S0 + S12) band ?UINT64MASK, #state{s0 = S0, s1 = S12}}.

-spec seed0() -> state().

%% @doc Set the default seed value to xorshift128plus state
%% in the process directory (Compatible with random:seed0/0).

seed0() ->
    #state{s0 = 1234567890123456789, s1 = 9876543210987654321}.

%% @doc Set the default seed value to xorshift128plus state
%% in the process directory %% (Compatible with random:seed/1).

-spec seed() -> state().

seed() ->
    case seed_put(seed0()) of
        undefined -> seed0();
        #state{s0 = _S0, s1 = _s1} = R -> R
    end.

%% @doc Put the seed, or internal state, into the process dictionary.

-spec seed_put(state()) -> 'undefined' | state().

seed_put(R) ->
    put(exsplus_seed, R).

%% @doc Set the seed value to xorshift128plus state in the process directory.
%% with the given three-element tuple of unsigned 32-bit integers
%% (Compatible with random:seed/1).

-spec seed({integer(), integer(), integer()}) -> 'undefined' | state().

seed({A1, A2, A3}) ->
    seed(A1, A2, A3).

%% @doc Set the seed value to xorshift128plus state in the process directory
%% with the given three unsigned 32-bit integer arguments
%% (Compatible with random:seed/3).
%% Multiplicands here: three 32-bit primes

-spec seed(integer(), integer(), integer()) -> 'undefined' | state().

seed(A1, A2, A3) ->
    S = ((A1 * 4294967197) * (A2 * 4294967231) * (A3 * 4294967279)
        rem 16#fffffffffffffffffffffffffffffffe) + 1,
    seed_put(#state{s0 = S band ?UINT64MASK, s1 = S bsr 64}).

%% @doc Generate float from
%% given xorshift128plus internal state.
%% (Note: 0.0 =&lt; result &lt; 1.0)
%% (Compatible with random:uniform_s/1)

-spec uniform_s(state()) -> {float(), state()}.

uniform_s(R0) ->
    {I, R1} = next(R0),
    {I / 18446744073709551616.0, R1}.

-spec uniform() -> float().

%% @doc Generate float
%% given xorshift128plus internal state
%% in the process dictionary.
%% (Note: 0.0 =&lt; result &lt; 1.0)
%% (Compatible with random:uniform/1)

uniform() ->
    R = case get(exsplus_seed) of
        undefined -> seed0();
        _R -> _R
    end,
    {V, R2} = uniform_s(R),
    put(exsplus_seed, R2),
    V.

%% @doc Generate integer from given xorshift128plus internal state.
%% (Note: 0 =&lt; result &lt; MAX (given positive integer))
-spec uniform_s(pos_integer(), state()) -> {pos_integer(), state()}.

uniform_s(Max, R) when is_integer(Max), Max >= 1 ->
    {V, R1} = next(R),
    {(V rem Max) + 1, R1}.

%% @doc Generate integer from the given TinyMT internal state
%% in the process dictionary.
%% (Note: 1 =&lt; result =&lt; N (given positive integer))
%% (compatible with random:uniform/1)

-spec uniform(pos_integer()) -> pos_integer().

uniform(N) when is_integer(N), N >= 1 ->
    R = case get(exsplus_seed) of
        undefined -> seed0();
        _R -> _R
    end,
    {V, R1} = uniform_s(N, R),
    put(exsplus_seed, R1),
    V.

