import Qpf.Qpf

namespace Macro
  open Lean Meta Elab Term

  #check optParam

  variable [MonadControlT MetaM n] [Monad n] [MonadLiftT MetaM n] 
            [MonadError n] [MonadLog n] [AddMessageContext n]
            [MonadQuotation n]


  #check @TypeFun.curried
  #check Exception

  /--
    Takes an expression `e` of type `CurriedTypeFun n` and returns an expression of type `TypeFun n`
    representing the uncurried version of `e`.
    Tries to prevent unneccesary `ofCurried / curried` roundtrips
  -/
  def uncurry (F : Expr) : n Expr := do
    mkAppM ``TypeFun.ofCurried #[F]

    --
    -- Although preventing unneccesary `ofCurried / curried` roundtrips seems like a good idea,
    -- leaving them in actually causes more definitional equality (e.g., in the `_02_Tree` example)
    --

    -- let n       ← mkFreshExprMVar (mkConst ``Nat)
    -- let F_inner ← mkFreshExprMVar (kind:=MetavarKind.synthetic) none
    -- let us      ← mkFreshLevelMVars 2
    -- let app     := mkApp2 (mkConst ``TypeFun.curried us) n F_inner
    
    -- dbg_trace "\nChecking defEq of {F} and {app}"
    -- if (←isDefEq F app) then
    --   if let some F' :=  (← getExprMVarAssignment? F_inner.mvarId!) then
    --     dbg_trace "yes: {F'}"
    --     return F'
    
    -- dbg_trace "no"
    -- mkAppM ``TypeFun.ofCurried #[F]

  

  def withLiveBinders [Inhabited α]
                  (binders : Array Syntax) 
                  (f : Array Expr → n α) : n α
  := do
    let u := mkLevelSucc <|← mkFreshLevelMVar;
    let decls := binders.map fun α => (
      α.getId, 
      fun _ => pure (mkSort u)
    )

    withLocalDeclsD decls f


  /--
    Takes an array of bracketed binders, and allocate a fresh identifier for each hole in the binders.
    Returns a pair of the binder syntax with all holes replaced, and an array of all bound identifiers,
    both pre-existing and newly created
  -/
  def mkFreshNamesForBinderHoles (binders : Array Syntax) : 
      n ((Array Syntax) × (Array Syntax)) 
  := do
    let mut bindersNoHoles := #[]
    let mut binderNames := #[]
  
    for stx in binders do
      let mut newArgStx := Syntax.missing
      let kind := stx.getKind

      if kind == `Lean.Parser.Term.instBinder then
        if stx[1].isNone then
          throwErrorAt stx "Instances without names are not supported yet"
          -- let id := mkIdentFrom stx (← mkFreshBinderName)
          -- binderNames := binderNames.push id
          -- newArgStx := stx[1].setArgs #[id, Syntax.atom SourceInfo.none ":"]
        else    
          dbg_trace stx[1]
          let id := stx[1][0]
          binderNames := binderNames.push id
          newArgStx := stx[1]

      else
        -- replace each hole with a fresh id
        let ids ← stx[1].getArgs.mapM fun id => do
          dbg_trace id
          let kind := id.getKind
          if kind == identKind then
            return id
          else if kind == `Lean.Parser.Term.hole then
            return mkIdentFrom id (← mkFreshBinderName)
          else 
            throwErrorAt id "identifier or `_` expected, found {kind}"
            
        for id in ids do
          binderNames := binderNames.push id
        newArgStx := stx[1].setArgs ids

      let newStx := stx.setArg 1 newArgStx
      bindersNoHoles := bindersNoHoles.push newStx

    return (bindersNoHoles, binderNames)


  /--
    Takes a list of binders, and split it into live and dead binders, respectively.
    For the live binders, return an array of with syntax of kind `binderIdent`, unwrapping 
    `simpleBinder` nodes if needed (while asserting that there were no type annotations)
  -/
  def splitLiveAndDeadBinders (binders : Array Syntax) : n (Array Syntax × Array Syntax) := do
    let mut liveVars := #[]
    let mut deadBinders := #[]

    let mut isLive := false
    for binder in binders do
      let kind := binder.getKind

      if kind == `Lean.binderIdent then
        isLive := true
        liveVars := liveVars.push binder

      else if kind == `Lean.Parser.Term.simpleBinder then
        isLive := true
        for id in binder[0].getArgs do
          liveVars := liveVars.push id

        if !binder[1].isNone then
          dbg_trace binder[1]
          throwErrorAt binder "live variable may not have a type annotation.\nEither add brackets to mark the variable as dead, or remove the type"

      else if isLive then
        throwErrorAt binder f!"Unexpected bracketed binder, dead arguments must precede all live arguments.\nPlease reorder your arguments or mark this binder as live by removing brackets and/or type ascriptions"

      else
        deadBinders := deadBinders.push binder
    return (liveVars, deadBinders)


  
  open Lean.Parser.Term in
  elab "#dbg_syntax " t:term : command => do
    dbg_trace t

  #dbg_syntax F (a:=2)
  
  open Lean.Parser.Term Elab.Command in
  elab "#dbg_expr " t:term : command => do
    let expr ← liftTermElabM none $ elabTerm t none
    dbg_trace expr
    dbg_trace expr.isForall

  #dbg_expr (Nat → Int)

end Macro
