module C.Loops

(* This modules exposes a series of combinators; they are modeled using
 * higher-order functions and specifications, and extracted, using a
 * meta-theoretic argument, to actual C loops. *)

open FStar.ST
open FStar.Buffer

module HH = FStar.HyperHeap
module HS = FStar.HyperStack
module UInt32 = FStar.UInt32

#set-options "--initial_fuel 0 --max_fuel 0 --z3rlimit 20"

(* To be extracted as:
  {
    int i = <start>;
    for (; i != <finish>; ++i) <f>;
  }
  // i need not be in scope after the loop
*)
val for:
  start:UInt32.t ->
  finish:UInt32.t{UInt32.v finish >= UInt32.v start} ->
  inv:(HS.mem -> nat -> Type0) ->
  f:(i:UInt32.t{UInt32.(v start <= v i /\ v i < v finish)} -> Stack unit
                        (requires (fun h -> inv h (UInt32.v i)))
                        (ensures (fun h_1 _ h_2 -> UInt32.(inv h_1 (v i) /\ inv h_2 (v i + 1)))) ) ->
  Stack unit
    (requires (fun h -> inv h (UInt32.v start)))
    (ensures (fun _ _ h_2 -> inv h_2 (UInt32.v finish)))
let rec for start finish inv f =
  if start = finish then
    ()
  else begin
    f start;
    for (UInt32.(start +^ 1ul)) finish inv f
  end

(* To be extracted as:
  {
    int i = <start>;
    for (; i != <finish>; --i) <f>;
  }
  // i need not be in scope after the loop
*)
val reverse_for:
  start:UInt32.t ->
  finish:UInt32.t{UInt32.v finish <= UInt32.v start} ->
  inv:(HS.mem -> nat -> Type0) ->
  f:(i:UInt32.t{UInt32.(v start >= v i /\ v i > v finish)} -> Stack unit
                        (requires (fun h -> inv h (UInt32.v i)))
                        (ensures (fun h_1 _ h_2 -> UInt32.(inv h_1 (v i) /\ inv h_2 (v i - 1)))) ) ->
  Stack unit
    (requires (fun h -> inv h (UInt32.v start)))
    (ensures (fun _ _ h_2 -> inv h_2 (UInt32.v finish)))
let rec reverse_for start finish inv f =
  if start = finish then
    ()
  else begin
    f start;
    reverse_for (UInt32.(start -^ 1ul)) finish inv f
  end

(* To be extracted as:
    int i = <start>;
    bool b = false;
    for (; (!b) && (i != <end>); ++i) {
      b = <f>;
    }
    // i and b must be in scope after the loop
*)
val interruptible_for:
  start:UInt32.t ->
  finish:UInt32.t{UInt32.v finish >= UInt32.v start} ->
  inv:(HS.mem -> nat -> bool -> GTot Type0) ->
  f:(i:UInt32.t{UInt32.(v start <= v i /\ v i < v finish)} -> Stack bool
                        (requires (fun h -> inv h (UInt32.v i) false))
                        (ensures (fun h_1 b h_2 -> inv h_1 (UInt32.v i) false /\ inv h_2 UInt32.(v i + 1) b)) ) ->
  Stack (UInt32.t * bool)
    (requires (fun h -> inv h (UInt32.v start) false))
    (ensures (fun _ res h_2 -> let (i, b) = res in ((if b then True else i == finish) /\ inv h_2 (UInt32.v i) b)))
let rec interruptible_for start finish inv f =
  if start = finish then
    (finish, false)
  else
    let start' = UInt32.(start +^ 1ul) in
    if f start
    then (start', true)
    else interruptible_for start' finish inv f

(* To be extracted as:
    int i = <start>;
    bool b = false;
    for (; (!b) && (i != <end>); --i) {
      b = <f>;
    }
    // i and b must be in scope after the loop    
*)
val interruptible_reverse_for:
  start:UInt32.t ->
  finish:UInt32.t{UInt32.v finish <= UInt32.v start} ->
  inv:(HS.mem -> nat -> bool -> GTot Type0) ->
  f:(i:UInt32.t{UInt32.(v start >= v i /\ v i > v finish)} -> Stack bool
                        (requires (fun h -> inv h (UInt32.v i) false))
                        (ensures (fun h_1 b h_2 -> inv h_1 (UInt32.v i) false /\ inv h_2 UInt32.(v i - 1) b)) ) ->
  Stack (UInt32.t * bool)
    (requires (fun h -> inv h (UInt32.v start) false))
    (ensures (fun _ res h_2 -> let (i, b) = res in ((if b then True else i == finish) /\ inv h_2 (UInt32.v i) b)))
let rec interruptible_reverse_for start finish inv f =
  if start = finish then
    (finish, false)
  else
    let start' = UInt32.(start -^ 1ul) in
    if f start
    then (start', true)
    else interruptible_reverse_for start' finish inv f


val seq_map:
  #a:Type -> #b:Type ->
  f:(a -> Tot b) ->
  s:Seq.seq a ->
  Tot (s':Seq.seq b{Seq.length s = Seq.length s' /\ 
    (forall (i:nat). {:pattern (Seq.index s' i)} i < Seq.length s' ==> Seq.index s' i == f (Seq.index s i))})
    (decreases (Seq.length s))
let rec seq_map #a #b f s =
  if Seq.length s = 0 then
    Seq.createEmpty
  else
    let s' = Seq.cons (f (Seq.head s)) (seq_map f (Seq.tail s)) in
    s'

(* To be substituted with its definition *)
val map:
  #a:Type0 -> #b:Type0 ->
  f:(a -> Tot b) ->
  output: buffer b ->
  input: buffer a{disjoint input output} ->
  l: UInt32.t{ UInt32.v l = Buffer.length output /\ UInt32.v l = Buffer.length input } ->
  Stack unit
    (requires (fun h -> live h input /\ live h output ))
    (ensures (fun h_1 r h_2 -> modifies_1 output h_1 h_2 /\ live h_2 input /\ live h_1 input /\ live h_2 output
      /\ live h_2 output
      /\ (let s1 = as_seq h_1 input in
         let s2 = as_seq h_2 output in
         s2 == seq_map f s1) ))
let map #a #b f output input l =
  let h0 = ST.get() in
  let inv (h1: HS.mem) (i: nat): Type0 =
    live h1 output /\ live h1 input /\ modifies_1 output h0 h1 /\ i <= UInt32.v l
    /\ (forall (j:nat). {:pattern (get h1 output j)} (j >= i /\ j < UInt32.v l) ==> get h1 output j == get h0 output j)
    /\ (forall (j:nat). {:pattern (get h1 output j)} j < i ==> get h1 output j == f (get h0 input j))
  in
  let f' (i:UInt32.t{ UInt32.( 0 <= v i /\ v i < v l ) }): Stack unit
    (requires (fun h -> inv h (UInt32.v i)))
    (ensures (fun h_1 _ h_2 -> UInt32.(inv h_2 (v i + 1))))
  =
    output.(i) <- f (input.(i))
  in
  for 0ul l inv f';
  let h1 = ST.get() in
  Seq.lemma_eq_intro (as_seq h1 output) (seq_map f (as_seq h0 input))