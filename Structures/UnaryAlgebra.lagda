%{{{ Imports
\begin{code}
module Structures.UnaryAlgebra where

open import Level renaming (suc to lsuc; zero to lzero)

open import Categories.Category   using (Category; module Category)
open import Categories.Functor    using (Functor; Contravariant)
open import Categories.Adjunction using (Adjunction)
open import Categories.Agda       using (Sets)
open import Forget

open import Data.Nat using (ℕ; suc)
open import Data.Product using (_×_; _,_ ; Σ; proj₁; proj₂; uncurry; map)

open import Function2
open import Function

open import EqualityCombinators
\end{code}
%}}}

%{{{ Unary ; Hom ; UnaryAlg ; UnaryCat ; Forget

A single-sorted |Unary| algebra consists of a type along with a function on that type.
For example, the naturals and addition-by-1 or lists and the reverse operation.

Along with functions that preserve the elected operation, such algberas form a category.

\begin{code}
record Unary {ℓ} : Set (lsuc ℓ) where
  constructor MkUnary
  field
    Carrier : Set ℓ
    Op      : Carrier → Carrier

open Unary

record Hom {ℓ} (X Y : Unary {ℓ}) : Set ℓ where
  constructor MkHom
  field
    mor        :  Carrier X → Carrier Y
    pres-op    :  mor ∘ Op X ≐  Op Y ∘ mor

open Hom

UnaryAlg : {ℓ : Level} → OneSortedAlg ℓ
UnaryAlg = record
  { Alg       = Unary
  ; Carrier   = Carrier
  ; Hom       = Hom
  ; mor       = mor
  ; comp      = λ F G → record
    { mor     =  mor F ∘ mor G
    ; pres-op =  λ a → ≡.trans (≡.cong (mor F) (pres-op G a)) (pres-op F (mor G a))
    }
  ; comp-is-∘ =  ≐-refl
  ; Id        =  MkHom id ≐-refl
  ; Id-is-id  =  ≐-refl
  }

UnaryCat : {ℓ : Level} → Category (lsuc ℓ) ℓ ℓ
UnaryCat {ℓ} = oneSortedCategory ℓ UnaryAlg

Forget : (ℓ : Level) → Functor (UnaryCat {ℓ}) (Sets ℓ)
Forget ℓ = mkForgetful ℓ UnaryAlg
\end{code}

%}}}


\begin{code}
-- An 'Eventually' type
data ForeverMaybe {ℓ} (A : Set ℓ) : Set ℓ where
  base : A → ForeverMaybe A
  step : ForeverMaybe A → ForeverMaybe A
--
-- Elements of this type are of the form |stepⁿ (base a)| for |a : A|.
--
-- really this is the ``term algebra'' over unary signatures.

fromFM : ∀{ℓ} {A : Set ℓ} → ForeverMaybe A → A
fromFM (base x) = x
fromFM (step m) = fromFM m
--
-- More generally,
--
iterateFM : ∀ {ℓ } {A : Set ℓ} (f : A → A) → ForeverMaybe A → A
iterateFM f (base x) = x
iterateFM f (step x) = f (iterateFM f x)
--
-- that is, |iterateFM f (stepⁿ base x) ≈ fⁿ x|

fmMap : ∀{a b}{A : Set a}{B : Set b} → (A → B) → ForeverMaybe A → ForeverMaybe B
fmMap F (base x) = base (F x)
fmMap F (step e) = step (fmMap F e)

iterateFM-nat : ∀ {o} {X Y : Unary {o}} (F : Hom X Y)
              → iterateFM (Op Y) ∘ fmMap (mor F) ≐ mor F ∘ iterateFM (Op X)
iterateFM-nat F (base x) = ≡.refl
iterateFM-nat {X = X} {Y = Y} F (step x) = begin
  (iterateFM (Op Y) ∘ fmMap (mor F) ∘ step) x
    ≡⟨ ≡.refl ⟩  -- definitions of fmMap and then iterateFM
  (Op Y ∘ iterateFM (Op Y) ∘ fmMap (mor F)) x
    ≡⟨ ≡.cong (Op Y) (iterateFM-nat F x) ⟩
  (Op Y ∘ mor F ∘ iterateFM (Op X)) x
    ≡⟨ ≡.sym (pres-op F _) ⟩ 
  (mor F ∘ Op X ∘ iterateFM (Op X)) x
    ≡⟨ ≡.refl ⟩ -- definition of iterateFM, in reverse
  (mor F ∘ iterateFM (Op X) ∘ step) x
     ∎
     where open ≡.≡-Reasoning {A = Carrier Y}

iterateFM-fmMap-id : ∀ {o} {X : Set o} → id {A = ForeverMaybe X} ≐ iterateFM step ∘ fmMap base
iterateFM-fmMap-id (base x) = ≡.refl
iterateFM-fmMap-id (step x) = ≡.cong step (iterateFM-fmMap-id x)

fmMap-id : ∀{a}  {A : Set a} → fmMap (id {A = A}) ≐ id
fmMap-id (base e) = ≡.refl
fmMap-id (step e) = ≡.cong step (fmMap-id e)

fmMap-∘ : ∀ {o} {X Y Z : Set o} {f : X → Y} {g : Y → Z}
        →  fmMap (g ∘ f) ≐ fmMap g ∘ fmMap f
fmMap-∘ (base x) = ≡.refl
fmMap-∘ (step e) = ≡.cong step (fmMap-∘ e)

fmMap-cong : ∀{o} {A B : Set o} {F G : A → B} → F ≐ G → fmMap F ≐ fmMap G
fmMap-cong eq (base x) = ≡.cong base (eq x)
fmMap-cong eq (step x) = ≡.cong step (fmMap-cong eq x)

Free : ∀ o → Functor (Sets o) (UnaryCat {o})
Free o = record
  { F₀             =   λ A → MkUnary (ForeverMaybe A) step
  ; F₁             =   λ f → MkHom (fmMap f) ≐-refl
  ; identity       =   fmMap-id
  ; homomorphism   =   fmMap-∘
  ; F-resp-≡      =   λ F≈G → fmMap-cong (λ _ → F≈G)
  }

AdjLeft : ∀ o → Adjunction (Free o) (Forget o)
AdjLeft o = record
  { unit     =   record { η = λ _ → base ; commute = λ _ → ≡.refl }
  ; counit   =   record { η = λ { (MkUnary A f) → MkHom (iterateFM f) ≐-refl} ; commute = iterateFM-nat }
  ; zig      =   iterateFM-fmMap-id
  ; zag      =   ≡.refl
  }
\end{code}

And now for a different way of looking at the same algebra.
We ``mark'' a piece of data with its depth.

\begin{code}
Free² : ∀ o → Functor (Sets o) (UnaryCat {o})
Free² o = record
  { F₀ = λ A → MkUnary (A × ℕ) (map id suc)
  ; F₁ = λ f → MkHom (map f id) (λ _ → ≡.refl)
  ; identity = ≐-refl
  ; homomorphism = ≐-refl
  ; F-resp-≡ = λ F≡G → λ { (x , n) → ≡.cong₂ _,_ (F≡G {x}) ≡.refl }
  }

iter : {o : Level} {A : Set o} (f : A → A) → A → ℕ → A
iter f x ℕ.zero = x
iter f x (suc n) = iter f (f x) n

-- important property of iteration
iter-ℕ : {o : Level} {A : Set o} {f : A → A} (a : A) (n : ℕ) → iter f (f a) n ≡ f (iter f a n)
iter-ℕ a ℕ.zero = ≡.refl
iter-ℕ {f = f} a (suc n) = iter-ℕ {f = f} (f a) n

-- iteration of commutable functions
iter-comm : {o : Level} {B C : Set o} {f : B → C} {g : B → B} {h : C → C} → (f ∘ g ≐ h ∘ f) →
  ∀ (b : B) (n : ℕ) → iter h (f b) n ≡ f (iter g b n)
iter-comm eq a ℕ.zero = ≡.refl
iter-comm {f = f} {g} {h} eq a (suc n) = 
  begin
    iter h (h (f a)) n ≡⟨ iter-ℕ (f a) n ⟩
    h (iter h (f a) n) ≡⟨ ≡.cong h (iter-comm eq a n) ⟩
    h (f (iter g a n)) ≡⟨ ≡.sym (eq (iter g a n)) ⟩
    f (g (iter g a n)) ≡⟨ ≡.cong f (≡.sym (iter-ℕ a n))  ⟩
    f (iter g (g a) n)
  ∎
  where open ≡.≡-Reasoning

×-induct : {a b c : Level} {A : Set a} {B : A → Set b} {C : Σ A B → Set c}
  (g : (a : A) (b : B a) → C (a , b)) → ((p : Σ A B) → C p)
×-induct g = uncurry g

-- There has to be a simpler way, but this will do
zig′ : {a : Level} {A : Set a} (x : A) (n : ℕ) →
  (x , n) ≡ iter (map id suc) (x , 0) n
zig′ _ ℕ.zero = ≡.refl
zig′ x (suc n) = ≡.sym (
  begin
    iter (map id suc) (map id suc (x , 0)) n ≡⟨ iter-ℕ (x , 0) n ⟩
    map id suc (iter (map id suc) (x , 0) n) ≡⟨ ≡.cong (map id suc) (≡.sym (zig′ x n)) ⟩
    map id suc (x , n) ≡⟨ ≡.refl ⟩
    (x , suc n)
  ∎)
  where open ≡.≡-Reasoning

AdjLeft² : ∀ o → Adjunction (Free² o) (Forget o)
AdjLeft² o = record
  { unit = record { η = λ _ x → x , 0 ; commute = λ _ → ≡.refl }
  ; counit = record
    { η = λ { (MkUnary A f) → MkHom (uncurry (iter f)) (uncurry iter-ℕ) }
    ; commute = λ { {MkUnary X x̂} {MkUnary Y ŷ} (MkHom f pres) → 
      uncurry (iter-comm {f = f} {x̂} {ŷ} pres) } }
  ; zig = uncurry zig′
  ; zag = ≡.refl
  }
  where
    open ≡.≡-Reasoning
\end{code}

% Quick Folding Instructions:
% C-c C-s :: show/unfold region
% C-c C-h :: hide/fold region
% C-c C-w :: whole file fold
% C-c C-o :: whole file unfold
%
% Local Variables:
% folded-file: t
% eval: (fold-set-marks "%{{{ " "%}}}")
% eval: (fold-whole-buffer)
% fold-internal-margins: 0
% end:
