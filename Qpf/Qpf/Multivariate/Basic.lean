/-
Copyright (c) 2018 Jeremy Avigad. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jeremy Avigad, Simon Hudon
-/
import Qpf.PFunctor.Multivariate.Basic
import Qpf.Mathlib

/-!
# Multivariate quotients of polynomial functors.

Basic definition of multivariate QPF. QPFs form a compositional framework
for defining inductive and coinductive types, their quotients and nesting.

The idea is based on building ever larger functors. For instance, we can define
a list using a shape functor:

```lean
inductive list_shape (a b : Type)
| nil : list_shape
| cons : a -> b -> list_shape
```

This shape can itself be decomposed as a sum of product which are themselves
QPFs. It follows that the shape is a QPF and we can take its fixed point
and create the list itself:

```lean
def list (a : Type) := fix list_shape a -- not the actual notation
```

We can continue and define the quotient on permutation of lists and create
the multiset type:

```lean
def multiset (a : Type) := qpf.quot list.perm list a -- not the actual notion
```

And `multiset` is also a QPF. We can then create a novel data type (for Lean):

```lean
inductive tree (a : Type)
| node : a -> multiset tree -> tree
```

An unordered tree. This is currently not supported by Lean because it nests
an inductive type inside of a quotient. We can go further and define
unordered, possibly infinite trees:

```lean
coinductive tree' (a : Type)
| node : a -> multiset tree' -> tree'
```

by using the `cofix` construct. Those options can all be mixed and
matched because they preserve the properties of QPF. The latter example,
`tree'`, combines fixed point, co-fixed point and quotients.

## Related modules

 * constructions
   * fix
   * cofix
   * quot
   * comp
   * sigma / pi
   * prj
   * const

each proves that some operations on functors preserves the QPF structure

## Reference

 * [Jeremy Avigad, Mario M. Carneiro and Simon Hudon, *Data Types as Quotients of Polynomial Functors*][avigad-carneiro-hudon2019]
-/


universe u

open_locale MvFunctor

/-- Multivariate quotients of polynomial functors.
-/
class MvQpf {n : ???} (F : TypeFun.{u,_} n) extends MvFunctor F  where
  P : MvPFunctor.{u} n
  abs : ??? {??}, P.Obj ?? ??? F ??
  repr : ??? {??}, F ?? ??? P.Obj ??
  abs_repr : ??? {??} x : F ??, abs (repr x) = x
  abs_map : ??? {?? ??} (f : ?? ??? ??) (p : P.Obj ??), abs (f <$$> p) = f <$$> abs p

namespace MvQpf

variable {n : ???} {F : TypeFun.{u,_} n} [q : MvQpf F]

include q

open MvFunctor (Liftp Liftr)

/-!
### Show that every mvqpf is a lawful mvfunctor.
-/


protected theorem id_map {?? : TypeVec n} (x : F ??) : TypeVec.id <$$> x = x := by
  rw [??? abs_repr x]
  cases' repr x with a f
  rw [??? abs_map]
  rfl

@[simp]
theorem comp_map {?? ?? ?? : TypeVec n} (f : ?? ??? ??) (g : ?? ??? ??) (x : F ??) : (g ??? f) <$$> x = g <$$> f <$$> x := by
  rw [??? abs_repr x]
  cases' repr x with a f
  rw [??? abs_map, ??? abs_map, ??? abs_map]
  rfl

instance (priority := 100) is_lawful_mvfunctor : LawfulMvFunctor F where
  id_map := MvQpf.id_map 
  comp_map := MvQpf.comp_map

-- Lifting predicates and relations
theorem liftp_iff {?? : TypeVec n} (p : ??? ???i???, ?? i ??? Prop) (x : F ??) :
    Liftp p x ??? ??? a f, x = abs ???a, f??? ??? ??? i j, p (f i j) := by
  constructor
  ?? rintro ???y, hy???
    cases' h : repr y with a f
    refine ???a, fun i j => (f i j).val, ?_???
    constructor
    ?? rw [??? hy, ??? abs_repr y, h, ??? abs_map]
      rfl
      
    intro i j
    apply (f i j).property
    
  rintro ???a, f, h???, h??????
  simp  at *
  use abs ???a, fun i j => ???f i j, h??? i j??????
  rw [??? abs_map, h???]
  rfl

theorem liftr_iff {?? : TypeVec n} (r : ??? {i}, ?? i ??? ?? i ??? Prop) (x y : F ??) :
    Liftr r x y ??? ??? a f??? f???, x = abs ???a, f?????? ??? y = abs ???a, f?????? ??? ??? i j, r (f??? i j) (f??? i j) := by
  constructor
  ?? rintro ???u, xeq, yeq???
    cases' h : repr u with a f
    refine ???a, fun i j => (f i j).val.fst, fun i j => (f i j).val.snd, ?_???
    constructor
    ?? rw [??? xeq, ??? abs_repr u, h, ??? abs_map]
      rfl
      
    constructor
    ?? rw [??? yeq, ??? abs_repr u, h, ??? abs_map]
      rfl
      
    intro i j
    exact (f i j).property
    
  rintro ???a, f???, f???, xeq, yeq, h???
  refine ???abs ???a, fun i j => ???(f??? i j, f??? i j), h i j??????, ?_???
  simp
  constructor
  ?? rw [xeq, ??? abs_map]
    rfl
    
  rw [yeq, ??? abs_map]
  rfl

open Set

open MvFunctor




theorem mem_supp {?? : TypeVec n} (x : F ??) i (u : ?? i) : 
  u ??? (supp x i) ??? ??? a f, abs ???a, f??? = x ??? u ??? Set.image (f i) Set.univ := 
by
  rw [supp]
  simp
  constructor
  ?? intro h a f haf
    have : Liftp (fun i u => u ??? Set.image (f i) Set.univ) x := by
      rw [liftp_iff]
      refine' ???a, f, haf.symm, _???
      intro i u
      simp [univ, image]
    let h_this := h this
    simp [Membership.mem, Set.mem, range, setOf] at h_this
    exact h_this
    
  intro h p
  rw [liftp_iff]
  rintro ???a, f, xeq, h'???
  rcases h a f xeq.symm with ???_, _, _???
  apply h'

theorem supp_eq {?? : TypeVec n} {i} (x : F ??) : 
  supp x i = { u | ??? a f, abs ???a, f??? = x ??? u ??? image (f i) univ } := 
by
  funext u
  have : _ := mem_supp x i u
  -- rcases this with ???left, right???
  simp [supp, setOf, Membership.mem, Set.mem, range] at this ???
  assumption

theorem has_good_supp_iff {?? : TypeVec n} (x : F ??) :
    (??? p, Liftp p x ??? ??? i u, u ??? supp x i ??? p i u) ???
      ??? a f, abs ???a, f??? = x ??? ??? i a' f', abs ???a', f'??? = x ??? image (f i) univ ??? image (f' i) univ :=
  by
  constructor
  ?? intro h
    have : Liftp (supp x) x := by
      rw [h]
      introv
      exact id
    rw [liftp_iff] at this
    rcases this with ???a, f, xeq, h'???
    refine' ???a, f, xeq.symm, _???
    intro a' f' h''
    rintro hu u ???j, h???, hfi???
    have hh : u ??? supp x a' := by
      rw [??? hfi] <;> apply h'
    refine' (mem_supp x _ u).mp hh _ _ hu
    
  rintro ???a, f, xeq, h??? p
  rw [liftp_iff]
  constructor
  ?? rintro ???a', f', xeq', h'??? i u usuppx
    rcases(mem_supp x _ u).mp (@usuppx) a' f' xeq'.symm with ???i, _, f'ieq???
    rw [??? f'ieq]
    apply h'
    
  intro h'
  refine' ???a, f, xeq.symm, _???
  intro j y
  apply h'
  rw [mem_supp]
  intro a' f' xeq'
  apply h _ a' f' xeq'
  simp [supp, setOf, Membership.mem, Set.mem, range]

variable (q)

/-- A qpf is said to be uniform if every polynomial functor
representing a single value all have the same range. -/
def IsUniform : Prop :=
  ??? ????? : TypeVec n??? a (a' : q.P.A) (f : q.P.B a ??? ??) (f' : q.P.B a' ??? ??),
    abs ???a, f??? = abs ???a', f'??? ??? ??? i, Set.image (f i) Set.univ = Set.image (f' i) Set.univ

/-- does `abs` preserve `liftp`? -/
def LiftpPreservation : Prop :=
  ??? ????? : TypeVec n??? (p : ??? ???i???, ?? i ??? Prop) (x : q.P.Obj ??), Liftp p (abs x) ??? Liftp p x

/-- does `abs` preserve `supp`? -/
def SuppPreservation : Prop :=
  ??? ???????? (x : q.P.Obj ??), supp (abs x) = supp x

variable (q)


theorem supp_eq_of_is_uniform (h : q.IsUniform) 
                              {?? : TypeVec n} 
                              (a : q.P.A) 
                              (f : q.P.B a ??? ??) 
                              (i : Fin2 n):
    supp (abs ???a, f???) i = Set.image (f i) Set.univ := 
by
  ext u
  let x := (abs ???a, f???)
  have : _ := mem_supp x i u
  rcases this with ???mem_supp_left, mem_supp_right???
  constructor
  ?? intro h'    
    apply mem_supp_left h'
    rfl
    
  . intro h'
    apply mem_supp_right
    intros a' f' e
    rw [???h _ _ _ _ e.symm i]
    exact h'
    
    
    

theorem liftp_iff_of_is_uniform (h : q.IsUniform) {?? : TypeVec n} (x : F ??) (p : ??? i, ?? i ??? Prop) :
    Liftp p x ??? ??? i u, u ??? supp x i ??? p i u := by
  rw [liftp_iff, ??? abs_repr x]
  cases' repr x with a f
  constructor
  ?? rintro ???a', f', abseq, hf??? u
    rw [supp_eq_of_is_uniform q h, h _ _ _ _ abseq]
    rintro b ???i, _, hi???
    rw [??? hi]
    apply hf
    
  intro h'
  refine' ???a, f, rfl, fun _ i => h' _ _ _???
  intros j i
  rw [supp_eq_of_is_uniform q h]
  exact ???i, mem_univ i, rfl???

theorem supp_map (h : q.IsUniform) {?? ?? : TypeVec n} (g : ?? ??? ??) (x : F ??) i : 
  supp (g <$$> x) i =  image (g i) (supp x i) := 
by
  rw [??? abs_repr x]
  cases' repr x with a f
  rw [??? abs_map, MvPFunctor.map_eq]
  rw [supp_eq_of_is_uniform q h, supp_eq_of_is_uniform q h]
  simp [Membership.mem, Set.mem, range, setOf, image, TypeVec.comp]
  funext x;
  apply Eq.propIntro;
  . rintro ???a???, h???, h??????
    refine ???f i a???, ?_???
    apply And.intro
    refine ???a???, ?_???
    apply And.intro h???
    rfl
    exact h???
  . rintro ???a???, ???a???, h???, h??????, h??????
    refine ???a???, ?_???
    apply And.intro
    exact h???
    cases h???
    exact h???



theorem supp_preservation_iff_uniform : q.SuppPreservation ??? q.IsUniform := by
  constructor
  ?? intro h ?? a a' f f' h' i
    rw [??? MvPFunctor.supp_eq, ??? MvPFunctor.supp_eq, ??? h, h', h]
    
  ?? rintro h ?? ???a, f???
    ext x
    rw [supp_eq_of_is_uniform q h, MvPFunctor.supp_eq]



theorem supp_preservation_iff_liftp_preservation : q.SuppPreservation ??? q.LiftpPreservation := by
  constructor <;> intro h
  ?? rintro ?? p ???a, f???
    have h' := h
    rw [supp_preservation_iff_uniform] at h'
    simp only [SuppPreservation, supp]  at h
    simp only [liftp_iff_of_is_uniform, supp_eq_of_is_uniform, MvPFunctor.liftp_iff', h',
                image_univ,mem_range,exists_imp_distrib]
    constructor
    . intros h??? i x
      apply h??? i (f i x) x
      rfl

    . intros h??? i u x h???
      cases h???
      apply h???
    
  ?? rintro ?? ???a, f???
    simp only [SuppPreservation] at h
    ext x
    simp [supp, h]
    apply congrArg
    ext y
    constructor
    all_goals
      intros h??? p hLift
      apply h???
      specialize h p ???a,f???
      rcases h with ???hl, hr???
    . apply hr
      assumption

    . apply hl
      assumption



    

theorem liftp_preservation_iff_uniform : q.LiftpPreservation ??? q.IsUniform := by
  rw [??? supp_preservation_iff_liftp_preservation, supp_preservation_iff_uniform]


  /-!
    ## Show that every polynomial functor is a QPF
  -/
  instance {n} (P : MvPFunctor n) : MvQpf P.Obj where
    P         := P
    abs       := id
    repr      := id
    abs_repr  := by intros; rfl;
    abs_map   := by intros; rfl;

end MvQpf








abbrev ToMvQpf {n} (F : CurriedTypeFun n) 
  := MvQpf (TypeFun.ofCurried F)


namespace MvQpf

  instance instCurriedOfCurried {F : TypeFun n} [q : MvQpf F] :
    MvQpf (TypeFun.ofCurried F.curried) :=
  cast (
    by simp only [TypeFun.ofCurried_curried_involution]
  ) q
    
end MvQpf