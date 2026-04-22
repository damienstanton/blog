# Formal Basis: Computational Type Theory & Algebraic Effects

This document grounds the harness-kit's formal specification in **Computational Type Theory (CTT)** as developed by Robert Harper (OPLSS 2018, building on Martin-Löf and Constable et al.) and **Algebraic Effects and Handlers** as developed by Andrej Bauer. It abstracts away specific language syntax and instead defines the system using inference rules and set-theoretic definitions.

This specification serves as a blueprint for implementing CTT in *any* host language that supports algebraic data types and recursion.

### Key References

- Harper, R. *Computational Type Theory*. Lectures at OPLSS 2018. [[1]](https://youtu.be/LE0SSLizYUI) [[2]](https://youtu.be/1U4w0159-Ls) [[3]](https://youtu.be/GzPMZ6RsihU) [[4]](https://youtu.be/pfOQ97iCIsk) [[5]](https://youtu.be/RhDuRmg-SdA)
- Martin-Löf, P. *Constructive Mathematics and Computer Programming*. 1979.
- Constable, R. et al. *Implementing Mathematics with the NuPRL Proof Development System*. 1986.
- Bauer, A. *Algebraic Effects and Handlers*. (Various lectures and publications.)
- Sterling, J. *On the role of PL theory*: "PL theory is advancing linguistic solutions to the contradiction between abstraction and composition." (after Reynolds, 1983)

### Foundational Principle

> Types are specifications of program **behavior**.

The plan is to develop type theory starting with computation, and developing a *theory of truth* based on proofs. The connection with formalisms (theories of proofs, formal derivation, etc.) comes later. The emphasis is *not* just playing the Coq/Agda/Lean video game — truth is defined by execution, not by derivation.

Judgements are *expressions of knowledge* in the intuitionistic sense (Brouwer): mathematics is a human activity, thus finite, and the only way to constrain facts about infinite structures is via algorithms. We agree on uniformity solely because of the fundamental faculties of the human mind w.r.t. computation.

---

# I. The Domain: Abstract Syntax

We define the universe of discourse. In CTT, there is **no syntactic distinction** between "terms" and "types." Types are simply expressions that evaluate to canonical type values. $M$ and $A$ are both *programs*, and are behavioral, not structural:

$$\begin{cases} A\ \text{type} \\ M \in A \end{cases}$$

Let $\mathcal{V}$ be a countably infinite set of variables. Let $\text{Expr}$ be the inductive set defined by:

### 1. Structural Forms

$$e ::= x \mid \lambda x.e \mid \text{ap}(e_1, e_2) \mid (e_1, e_2) \mid e.1 \mid e.2$$

- $x \in \mathcal{V}$ — variable reference
- $\lambda x.e$ — function abstraction (binds $x$ in $e$)
- $\text{ap}(e_1, e_2)$ — function application
- $(e_1, e_2)$ — pair formation
- $e.1, e.2$ — first and second projection

### 2. The Finite Domain (Bool)

$$e ::= \ldots \mid \text{true} \mid \text{false} \mid \text{if}(e_1; e_2)(e)$$

- $\text{true}, \text{false}$ — canonical Boolean values
- $\text{if}(e_1; e_2)(e)$ — conditional: if $e$ then $e_1$ else $e_2$

### 3. The Inductive Domain (Nat)

$$e ::= \ldots \mid 0 \mid \text{succ}(e) \mid \text{rec}(e_0; a, b. e_1)(e)$$

- $0$ — zero
- $\text{succ}(e)$ — successor
- $\text{rec}(e_0; a, b. e_1)(e)$ — primitive recursion (base case $e_0$; step case $e_1$ binding predecessor $a$ and recursive result $b$)

### 4. The Dependent Families ($\Pi$, $\Sigma$)

$$e ::= \ldots \mid a\!:\!A_1 \to A_2 \mid a\!:\!A_1 \times A_2$$

- $a\!:\!A_1 \to A_2$ — dependent function type ($\Pi$-type). When $a$ does not appear free in $A_2$, this reduces to $A_1 \to A_2$.
- $a\!:\!A_1 \times A_2$ — dependent pair type ($\Sigma$-type). When $a$ does not appear free in $A_2$, this reduces to $A_1 \times A_2$.

A family of types indexed by a type:

$$n : \text{Nat} \gg \text{seq}(n)\ \text{type}$$

means $\text{seq}(n)\ \text{type}$ precisely when $n \in \text{Nat}$. In NuPRL notation:

$$f \in n\!:\!\text{Nat} \to \text{Seq}(n)$$

sometimes written $\Pi\, n\!:\!\text{Nat}.\ \text{Seq}(n)$.

### 5. Algebraic Effects (Bauer)

An operation symbol with arity $n$:

$$Op : A^n \to A$$

For example, $\text{plus} : 1 \times \mathbb{Z}^2 \to \mathbb{Z}$, encoding `3 + (4 + 5)` as:

```
plus(b:2  if b = 0 then 3
          else plus(c:2  if c = 0 then 4
                         else 5))
```

Generalizing with a parameter type $B$ (a monad):

$$Op : B \times A^n \to A$$

Generalizing further with a continuation type $C$ (a delimited continuation):

$$Op : B \times A^C \to A$$

where $C$ may be unbounded. This captures the full generality of algebraic effect signatures: an operation takes a parameter from $B$ and a continuation from $C \to A$, producing a result in $A$.

### 6. Type Formers as Expressions

Because types *are* expressions, type-level computation is first-class:

$$\text{if}(\text{Nat}; \text{Bool})(M)$$

is a type precisely when $M \in \text{Bool}$. And:

$$\text{if}(17; \text{true})(M) \in \text{if}(\text{Nat}; \text{Bool})(M)$$

This explains why a deterministic operational semantics is required: it is *the same $M$* in the type and term positions during simplification. Types/specifications **are** programs.

---

# II. The Dynamics: Operational Semantics

In CTT, truth is defined by execution. We define a **deterministic transition system** via a partial function $\mapsto$.

We have forms of expression $E$, and two judgement forms:

$$E\ \text{val} \qquad\qquad E \mapsto E'$$

These mean that $E$ is fully evaluated (a value), and that we have performed one simplification of $E$, respectively.

We have a derived notion of *big-step evaluation*:

$$E \Downarrow E_\circ \quad\stackrel{\text{def}}{=}\quad E \mapsto^\star E_\circ\ \text{val}$$

### 1. Canonical Forms (Values)

We define a predicate $\text{val}$ which holds if an expression is fully evaluated:

$$\frac{}{\text{true}\ \text{val}} \qquad \frac{}{\text{false}\ \text{val}}$$

$$\frac{}{0\ \text{val}} \qquad \frac{}{\text{succ}(M)\ \text{val}}$$

$$\frac{}{\lambda a. M\ \text{val}} \qquad \frac{}{(M_1, M_2)\ \text{val}}$$

### 2. Transition Rules ($\mapsto$)

The relation $E \mapsto E'$ denotes a single step of computation.

**Conditional:**

$$\frac{E \mapsto E'}{\text{if}(E_1; E_2)(E) \mapsto \text{if}(E_1; E_2)(E')}$$

$$\frac{}{\text{if}(E_1; E_2)(\text{true}) \mapsto E_1}$$

$$\frac{}{\text{if}(E_1; E_2)(\text{false}) \mapsto E_2}$$

**Application ($\beta$-reduction):**

$$\frac{M \mapsto M'}{\text{ap}(M, M_1) \mapsto \text{ap}(M', M_1)}$$

$$\frac{}{\text{ap}(\lambda a. M_2, M_1) \mapsto M_2[M_1/a]}$$

**Projection:**

$$\frac{M \mapsto M'}{M.i \mapsto M'.i}$$

$$\frac{}{(M_1, M_2).i \mapsto M_i} \qquad (i = 1, 2)$$

**Recursion:**

Let $R \coloneqq \text{rec}(M_\circ; a, b. M_1)(M)$. Then:

$$\frac{M \mapsto M'}{R \mapsto \text{rec}(M_\circ; a, b. M_1)(M')}$$

$$\frac{}{\text{rec}(M_\circ; a, b. M_1)(0) \mapsto M_\circ}$$

$$\frac{}{\text{rec}(M_\circ; a, b. M_1)(\text{succ}(M)) \mapsto M_1[M,\, R(M) / a, b]}$$

**Big-Step Evaluation ($\Downarrow$):** We define $E \Downarrow E_\circ$ as the reflexive-transitive closure of $\mapsto$ reaching a canonical form.

---

# III. The Verifier: Judgemental Equality

This is the core of CTT. A type *is* a specification of behavior. We define the master judgement:

$$\Gamma \vdash M \doteq M' \in A$$

"$M$ and $M'$ are equal inhabitants of type $A$ under context $\Gamma$."

### Computational Semantics of Type Equality

$A \doteq A'$ means:

$$A \doteq A' \quad\stackrel{\text{def}}{=}\quad \begin{cases} A \Downarrow A_\circ \\ A' \Downarrow A'_\circ \\ A_\circ \doteq_\circ A'_\circ \end{cases}$$

where $A_\circ$ and $A'_\circ$ are equal *type-values*, what Martin-Löf called **canonical types**.

### Computational Semantics of Element Equality

$M \doteq_A M'$ (also written $M \doteq M' \in A$) means:

Given that $A \Downarrow A_\circ$ and $A_\circ \doteq_\circ A_\circ$:

$$\begin{cases} M \Downarrow M_\circ \\ M' \Downarrow M'_\circ \\ M_\circ \doteq_\circ M'_\circ \in A_\circ \end{cases}$$

**Key insight on equality:** As a type structure gets richer, *when two things are equal is a property of the type they inhabit*, and it can be arbitrarily complicated. The situation about what is true has an unbounded quantifier complexity, whereas any formalism is always relentlessly recursively enumerable. This means formalisms can never approach equality-based truth. This standpoint is validated by Gödel's theorem.

For example:

- $2 \doteq 4 \in \text{Nat}$ cannot be true.
- $2 \doteq 4 \in \text{Nat}/2\ (\text{evens})$ *is* true — it always depends on type inhabitants.

This is in contrast to the older tradition of axioms as somehow type-independent. By the principle of propositions-as-types, we now know that is a logical fallacy.

### Algorithm

To verify $M \doteq M' \in A$:

1. Evaluate $A \Downarrow A_\circ$.
2. Evaluate $M \Downarrow M_\circ$.
3. Evaluate $M' \Downarrow M'_\circ$.
4. Switch on the structure of $A_\circ$:

### 1. The Boolean Specification

$\text{Bool} \doteq_\circ \text{Bool}$ — $\text{Bool}$ names a type-value.

$M_\circ \doteq_\circ M'_\circ \in \text{Bool}$ is the **strongest** (extremal) relation $\mathcal{R} \subseteq (\text{Expr} \times \text{Expr})$ such that:

$$\begin{cases} \text{true} \doteq_\circ \text{true} \in \text{Bool} \\ \text{false} \doteq_\circ \text{false} \in \text{Bool} \end{cases}$$

The extremal clause: (1) the stated conditions hold; (2) nothing else.

Equivalently, $M \doteq M' \in \text{Bool}$ iff either:

$$\binom{M \Downarrow \text{true}}{M' \Downarrow \text{true}} \qquad\text{or}\qquad \binom{M \Downarrow \text{false}}{M' \Downarrow \text{false}}$$

**Fact.** If $M \in \text{Bool}$ and $A\ \text{type}$ and $M_1 \in A$ and $M_2 \in A$, then $\text{if}(M_1; M_2)(M) \in A$.

*Proof.*
- $\_ \in \text{Bool}$ is given by a universal property, the least/most containing $\begin{cases} \text{true} \in \text{Bool} \\ \text{false} \in \text{Bool} \end{cases}$
- Fix some type $A$, $M_1 \in A$, $M_2 \in A$.
- If $M \in \text{Bool}$ then $\text{if}(M_1; M_2)(M) \in A$.
- $M \in \text{Bool}$ means $M \Downarrow M_\circ$ and either $M_\circ \doteq \text{true}$ or $M_\circ \doteq \text{false}$.
- It suffices to show $\begin{cases} \text{if}(M_1; M_2)(\text{true}) \in A \\ \text{if}(M_1; M_2)(\text{false}) \in A \end{cases}$
- $\text{if}$ evaluates its principal argument (via a transition step). Typing is closed under **head-expansion** (reverse execution). $\blacksquare$

**Dependent elimination (Shannon expansion).** If $a : \text{Bool} \gg B\ \text{type}$ and $M_1 \in B[\text{true}/a]$ and $M_2 \in B[\text{false}/a]$ and $M \in \text{Bool}$, then:

$$\text{if}(M_1; M_2)(M) \in B[M/a]$$

Generalized: if $a : \text{Bool} \gg P \in B$ then $P[M/a] \doteq \text{if}(P[\text{true}/a]; P[\text{false}/a])(M)$.

This can be seen as a "pivot on $M$." Binary decision diagrams are created by choosing pivots that minimize the size of conditionals.

### 2. The Natural Number Specification

$\text{Nat} \doteq_\circ \text{Nat}$.

$M \doteq M' \in \text{Nat}$ is the extremal (strongest/least) relation such that:

- Either $\binom{M \Downarrow 0}{M' \Downarrow 0}$
- Or $\binom{M \Downarrow \text{succ}(N)}{M' \Downarrow \text{succ}(N')}$ and $N \doteq N' \in \text{Nat}$

The extremal clause provides a morally-equivalent notion of an **induction principle**.

**Coinduction and divergence.** We can define the $Y$-combinator:

$$\text{fix}(a.\text{succ}(a)) \mapsto \omega \coloneqq \text{succ}(\text{fix}(a.\text{succ}(a)))$$

Then $\omega \in \text{CoNat}$ (the *greatest* solution to the specification), but $\omega \notin \text{Nat}$.

$(\text{Bool}, \text{Nat})$ are representative examples of **inductive** types (least extremal clauses). They are *not* representative of **coinductive** types (greatest extremal clauses).

**Fact.** If $a : \text{Nat} \gg B\ \text{type}$ and $M_\circ \in B[0/a]$ and $a : \text{Nat},\, b : B \gg M_1 \in B[\text{succ}(a)/a]$ and $M \in \text{Nat}$, then $\text{rec}(M_\circ; a, b. M_1)(M) \in B[M/a]$.

*Proof (case for 0):*
- $M \Downarrow 0$, so $M \doteq 0 \in \text{Nat}$ by head expansion.
- $M_\circ \in B[0/a] \doteq B[M/a]$.
- $R(M) \doteq R(0) \doteq M_\circ$.
- $R(M) \in B[M/a]$. $\blacksquare$

*Case for $\text{succ}(N)$:*
- $M \Downarrow \text{succ}(N)$.
- By inductive hypothesis, $R(N) \in B[N/a]$. (The full proof follows by the induction principle.)

### 3. The Function Specification (Extensionality)

$$A_1 \to A_2 \doteq A'_1 \to A'_2 \quad\text{iff}\quad A_1 \doteq A'_1 \text{ and } A_2 \doteq A'_2$$

$M \doteq M' \in A_1 \to A_2$ iff:

$$M \Downarrow \lambda a. M_2 \quad\text{and}\quad M' \Downarrow \lambda a. M'_2$$

where $a : A_1 \gg M_2 \doteq M'_2 \in A_2$.

**Fact.** If $M \in A_1 \to A_2$ and $M_1 \in A_1$ then $\text{ap}(M, M_1) \in A_2$.

In standard type-theoretic notation:

$$\frac{\Gamma \vdash M : A_1 \to A_2 \qquad \Gamma \vdash M_1 : A_1}{\Gamma \vdash \text{ap}(M, M_1) : A_2}$$

**Quantifier complexity.** What is the quantifier complexity of $M \doteq M' \in \text{Nat} \to \text{Nat}$? Informally:

$$\forall\, M_1 \doteq M'_1 \in \text{Nat}\quad \exists\, P_1 \doteq P'_1 \in \text{Nat} \quad\text{s.t.}\quad \text{ap}(M, M_1) \doteq \text{ap}(M', M'_1) \in \text{Nat}$$

This is why starting with formal syntax is inadequate: an induction rule like $\frac{}{\Gamma \vdash M \equiv M' : \text{Nat} \to \text{Nat}}$ is a derivation tree with quantifier complexity of "there exists." But $\forall\,\exists$ *cannot be captured by $\exists$ alone*!

This is profound: one **cannot axiomatize equality** in $\text{Nat} \to \text{Nat}$, by a deeper understanding of Gödel's theorem.

**Function extensionality.** If $M, M' \in A_1 \to A_2$ and $a : A_1 \gg \text{ap}(M, a) \doteq \text{ap}(M', a)$, then $M \doteq M' \in A_1 \to A_2$.

### 4. The Product Specification

$$(A_1 \times A_2) \doteq (A'_1 \times A'_2) \quad\text{iff}\quad A_1 \doteq A'_1 \text{ and } A_2 \doteq A'_2$$

$M \doteq M' \in (A_1 \times A_2)$ iff:

$$\begin{cases} M \Downarrow \langle M_1, M_2 \rangle \\ M' \Downarrow \langle M'_1, M'_2 \rangle \end{cases}$$

where $M_n \doteq M'_n \in A_n$.

**Fact.** If $M \in A_1 \times A_2$ then $M.1 \in A_1$ and $M.2 \in A_2$.

Note: if $M_1 \in A_1$, then $(M_1, M_2).1 \doteq M_1 \in A_1$, which has **no requirement** on $M_2$. By head-expansion, $(M_1, M_2).1 \mapsto M_1$. This may seem like a technical anomaly, but is an important insight: CTT relies on *specifications* as opposed to a grammar for writing down well-formed things according to syntactic rules. **Formalisms are about obeying protocols.**

### 5. The Dependent Function Specification ($\Pi$)

$$a\!:\!A_1 \to A_2 \doteq a\!:\!A'_1 \to A'_2 \quad\text{iff}\quad A_1 \doteq A'_1 \text{ and } a : A_1 \gg A_2 \doteq A'_2$$

$M \doteq M' \in (a\!:\!A_1 \to A_2)$ iff $M \Downarrow \lambda a. M_2$ and $M' \Downarrow \lambda a. M'_2$ where:

$$a : A_1 \gg M_2 \doteq M'_2 \in A_2(a)$$

The meaning: if $M_1 \doteq M'_1 \in A_1$ then:

$$M_2[M_1/a] \doteq M'_2[M'_1/a] \in A_2[M_1/a] \doteq A_2[M'_1/a]$$

**Fact.** If $M \in a\!:\!A_1 \to A_2$ and $M_1 \in A_1$ then $\text{ap}(M, M_1) \in A_2[M_1/a]$.

### 6. The Dependent Pair Specification ($\Sigma$)

$$a\!:\!A_1 \times A_2 \doteq a\!:\!A'_1 \times A'_2 \quad\text{iff}\quad A_1 \doteq A'_1 \text{ and } a : A_1 \gg A_2 \doteq A'_2$$

$M \doteq M' \in (a\!:\!A_1 \times A_2)$ iff $\begin{cases} M \Downarrow \langle M_1, M_2 \rangle \\ M' \Downarrow \langle M'_1, M'_2 \rangle \end{cases}$ where $M_1 \doteq M'_1 \in A_1$ and, different from simple products:

$$M_2 \doteq M'_2 \in A_2[M_1/a] \doteq A_2[M'_1/a]$$

which encodes the **dependency** between $A_1$ and $A_2$.

**Fact.** If $M \in a\!:\!A_1 \times A_2$ then $M.1 \in A_1$ and $M.2 \in A_2[M.1/a]$.

---

# IV. Functionality & Contexts

### Contexts

A **context** $\Gamma$ is an ordered list of hypotheses:

$$\Gamma ::= \cdot \mid \Gamma, x : A$$

### Functionality (The Fundamental Lemma of CTT)

Families (of types, of elements) must respect **equality of indices**. This is the central structural property.

$a : A \gg B \doteq B'$ means: if $M \doteq M' \in A$ then $B[M/a] \doteq B'[M'/a]$.

$a : A \gg N \doteq N' \in B$ means: if $M \doteq M' \in A$ then $N[M/a] \doteq N'[M'/a] \in B[M/a] \doteq B[M'/a]$ (assuming $a : A \gg B \doteq B$).

**Check:** $\begin{cases} a : A \gg B \text{ where } B \doteq B \\ M \doteq M' \in A \\ \text{implies } B[M/a] \doteq B[M'/a] \end{cases}$

**Example:** $\text{seq}(2+2)$ must be the same type as $\text{seq}(4)$. This is verified by reducing the index terms to canonical forms. If they reduce to the same value, the types are equal.

Similarly: $\text{seq}(\text{if}(17; 18)(M))$ is the same as $\text{if}(\text{seq}(17); \text{seq}(18))(M)$.

### Equisatisfaction

Equal indices deterministically produce equal results. This is why a deterministic operational semantics is a necessity. The term for this property is **equisatisfaction**.

### The Hypothetical Judgement

$a : A \gg B\ \text{type}$ means $B$ is a family of types that depends functionally on $a : A$.

$$M \doteq M' \in A \implies B[M/a] \doteq B[M'/a]$$

$a : A \gg N \in B$ means $N$ is a family of *elements* — a mapping.

$$M \doteq M' \in A \implies N[M/a] \doteq N[M'/a] \in B[M/a] \doteq B[M'/a]$$

---

# V. Propositions as Types (Curry-Howard)

Formal logic statements and their corresponding types:

| Logic | Type | Name |
|---|---|---|
| $\top^\star$ | $1$ | unit |
| $\bot^\star$ | $0$ | void |
| $(\Phi_1 \land \Phi_2)^\star$ | $\Phi_1^\star \times \Phi_2^\star$ | product |
| $(\Phi_1 \lor \Phi_2)^\star$ | $\Phi_1^\star + \Phi_2^\star$ | sum |
| $(\Phi_1 \supset \Phi_2)^\star$ | $\Phi_1^\star \to \Phi_2^\star$ | function |
| $(\forall a\!:\!A.\, \Phi_a)^\star$ | $a\!:\!A \to \Phi_a^\star$ | dependent function ($\Pi$) |
| $(\exists a\!:\!A.\, \Phi_a)^\star$ | $a\!:\!A \times \Phi_a^\star$ | dependent pair ($\Sigma$) |

### The Simple Dependent Type System

In summary, we have developed a simple, inherently computational dependent type system:

$$\tau \coloneqq \text{Bool} \mid \text{Nat} \mid a\!:\!A_1 \times A_2 \mid a\!:\!A_1 \to A_2$$

which can be used to prove the earlier claim:

$$\text{if}(17; \text{true})(M) \in \text{if}(\text{Nat}; \text{Bool})(M)$$

---

# VI. Formalisms

Formal type theory is inductively defined by derivation rules. We express "definitional equality":

$$\Gamma \vdash A : \text{Type} \qquad \Gamma \vdash M : A \qquad \Gamma \vdash A \equiv A' \qquad \Gamma \vdash M \equiv M' : A$$

Standard axioms:

$$\frac{}{\Gamma, x\!:\!A, \Gamma' \vdash x : A}$$

$$\frac{\Gamma \vdash M : A \qquad \Gamma \vdash A \equiv A'}{\Gamma \vdash M : A'}$$

$$\frac{\Gamma \vdash A_1 \qquad \Gamma \vdash A_2}{\Gamma \vdash A_1 \times A_2}$$

$$\frac{\Gamma \vdash M_1 : A_1 \qquad \Gamma \vdash M_2 : A_2}{\Gamma \vdash (M_1, M_2) : A_1 \times A_2}$$

$$\frac{\Gamma \vdash M : A_1 \times A_2}{\Gamma \vdash M.i : A_i}$$

$$\frac{\Gamma \vdash M_1 : A_1 \qquad \Gamma \vdash M_2 : A_2}{\Gamma \vdash (M_1, M_2).i \equiv M_i : A_i}$$

$$\frac{\Gamma \vdash M : A_1 \times A_2}{\Gamma \vdash (M.1, M.2) \equiv M : A_1 \times A_2}$$

### Relationship to Semantics

These "little lemmas" throughout are the method of **logical relations**: type-indexed information determines what equality means. Semantics define what *is true*, and formalisms that follow are a pale approximation useful for implementation.

The given facts look like definitions in a formal type system, and this is intentional. But the key insight: the *semantics* is primary, the *syntax* is secondary.

---

# VII. Algebraic Effects & Handlers

Following Bauer, we extend the computational framework with algebraic effects, providing a principled account of side effects within the type-theoretic framework.

### Effect Signatures

An algebraic effect is described by a set of **operation symbols**, each with a parameter type and continuation type:

$$Op : B \times A^C \to A$$

- $B$ — the parameter type (what the operation receives)
- $C$ — the continuation arity type (how many ways the handler can resume)
- $A$ — the result type

**Specializations:**

| Form | Meaning |
|---|---|
| $Op : A^n \to A$ | Fixed arity $n$ (finite choice) |
| $Op : B \times A^n \to A$ | Parameterized with finite continuation |
| $Op : B \times A^C \to A$ | Full generality: parameterized with unbounded continuation (delimited continuation) |

### Relationship to CTT

In the CTT framework, an effect handler is a computational object that *interprets* operation symbols by providing transition rules. The deterministic semantics of CTT extends to effectful computation:

- **Pure computation:** $E \mapsto E'$ as defined in Section II.
- **Effectful computation:** An expression may *perform* an operation $\text{do}(Op, v, k)$ where $v$ is the parameter value and $k$ is the continuation.
- **Handling:** A handler wraps a computation and provides interpretations for each operation symbol, restoring deterministic evaluation.

This preserves the fundamental CTT property: types remain specifications of behavior, but the behavior now includes the effect protocol. An effectful function type specifies not just input-output behavior but also which effects may be performed.

---

# VIII. Generic Implementation Strategy

To implement this in any language $\mathcal{L}$ (Rust, Swift, Java, etc.):

### 1. Define ADTs

Create a recursive sum type / enum for `Expr`, covering all forms from Section I.

### 2. Total Evaluator

Implement `eval(Expr) -> Result<Expr, Error>`. It *must* define a maximum stack depth or "gas" to ensure totality (termination) in the presence of general recursion ($Y$-combinator). The evaluator implements the transition rules of Section II.

### 3. Equivalence Checker

Implement `check_eq(Env, Type, Term1, Term2) -> bool`.

- This function **drives** the type system.
- It relies on `eval` to normalize terms to canonical forms.
- It recurses based on the shape of `Type`, implementing the type-indexed equality specifications of Section III.

### 4. No Exceptions (CTT Principle: Error as Data)

Treat "stuck terms" (e.g., applying a non-function, projecting a non-pair) as data variants (e.g., `Result::Err(Stuck)`), not runtime crashes. This aligns with the harness-kit's error handling: `PhaseResult<T>` always returns structured data, never throws.

### The "Proof"

A program $M$ "type checks" if and only if:

$$M \doteq M \in \text{ExpectedType}$$

This asserts that $M$ is a valid inhabitant of the specification `ExpectedType` — it evaluates to a canonical form that satisfies the type's behavioral specification.

---

# IX. Design Consequences: Value Semantics and Compositional Discipline

The formal system above is not merely descriptive — it is *prescriptive*. Certain programming paradigms are **structurally incompatible** with CTT's requirements, and others are **required** by them. These are not style preferences; they are direct consequences of the operational semantics, judgemental equality, and functionality.

## 1. Value Semantics Are Required (from §I–II)

CTT defines canonical forms — fully evaluated, self-contained values:

$$\text{true}\ \text{val} \qquad \text{false}\ \text{val} \qquad 0\ \text{val} \qquad \text{succ}(M)\ \text{val} \qquad \lambda a. M\ \text{val} \qquad (M_1, M_2)\ \text{val}$$

The entire type system is defined in terms of evaluation to these canonical forms: $E \Downarrow E_\circ\ \text{val}$. When we say $M \in A$, we mean $M \Downarrow M_\circ$ and $M_\circ$ satisfies the canonical form conditions of $A$. This is a statement about the **value** that $M$ evaluates to — not about some mutable heap state that could change between observations.

There is no concept of "mutating a value in place" in the dynamics. The transition $E \mapsto E'$ produces a *new* expression; it does not modify $E$. Canonical forms are final: once $E_\circ\ \text{val}$, no further transitions occur. Judgemental equality $M \doteq M' \in A$ is therefore **atemporal** — it does not depend on when the comparison happens.

**Consequence:** Regardless of the host language's memory model (stack, heap, reference counting, tracing GC, ownership), the observable semantics must be **value-based**. An implementation may use references internally for efficiency (Rust's ownership and borrowing, Swift's copy-on-write, persistent data structures), but the observable behavior must be indistinguishable from pure value semantics. Two expressions that evaluate to the same canonical form must be equal forever: $M \doteq M' \in A$ must be stable under all subsequent computation.

This is why the harness-kit mandates `Result<T, E>` return types, immutable artifact schemas, and content-hash-based IDs — all are direct expressions of value semantics.

## 2. Mutative Inheritance Is Incompatible (from §III)

CTT defines type membership by evaluation to canonical forms and **structural** comparison:

$$M \doteq M' \in A \quad\text{iff}\quad M \Downarrow M_\circ,\; M' \Downarrow M'_\circ,\; M_\circ \doteq_\circ M'_\circ \in A_\circ$$

We look at the *shape* of the canonical form and recurse. For Bool, we check if both evaluate to $\text{true}$ or both to $\text{false}$. For functions, we check extensional equality (§III.3). The entire verification procedure is structural — it examines the *value*, not any hidden metadata.

Mutative (implementation) inheritance violates this in three ways:

### a) Non-canonical dispatch

In class-based OOP, method calls resolve through vtable lookup at runtime. If $M$ is a subclass instance, $\text{ap}(M, x)$ may dispatch to a different method body than if $M$ were the superclass. The canonical form of $M$ now depends on its *runtime class*, which is hidden state not captured by the type $A$.

CTT requires that $M \in A_1 \to A_2$ means $M \Downarrow \lambda a. M_2$ — the function body is **structurally present** in the canonical form, not looked up through an indirection table. Dynamic dispatch makes the transition relation $\mapsto$ depend on hidden state (the vtable pointer), which violates the requirement for a deterministic transition system defined purely by expression structure.

### b) Fragile base class (violates Functionality, §IV)

If a base class changes its implementation, all subclass expressions change meaning. This violates functionality: $B[M/a]$ should depend only on the *value* of $M$ in $A$, not on the implementation details of $M$'s class hierarchy. Changing a base class changes the effective value of every subclass instance, breaking equisatisfaction: the "same" expression no longer evaluates to the "same" canonical form.

### c) Identity vs. structural equality

OOP distinguishes reference identity (`===`, pointer equality) from value equality (`==`, structural comparison). CTT has exactly **one** notion of equality: $M \doteq M' \in A$, defined structurally by evaluation to canonical forms. Reference identity has no semantic content in CTT — two expressions are equal if and only if they evaluate to equal canonical forms, regardless of where they reside in memory.

## 3. Mixins Are Incompatible (from §IV)

Mixins introduce implicit composition through linearized inheritance (method resolution order). Given a class composed from multiple mixins, method resolution depends on the MRO algorithm (e.g., C3 linearization), which is a *syntactic* property of the class definition.

This violates functionality (§IV): $B[M/a]$ must be determined solely by the value of $M$ in $A$, but with mixins, the "value" of a method call depends on the **order** of mixin composition. Two classes with the same set of mixins but different ordering may exhibit different behavior — the same logical composition produces different results depending on incidental syntactic arrangement.

Furthermore, mixins typically introduce **shared mutable state** through `self` / `this`, creating implicit coupling between components. Given two mixins $X$ and $Y$ that both mutate a shared field via `self`, the meaning of $\text{ap}(M, x)$ depends on which mixin ran most recently — a temporal dependency that CTT's atemporal judgemental equality cannot express.

## 4. What to Use Instead (from §I, §V, §VII)

CTT provides the correct compositional primitives — the ones that *do* satisfy the operational semantics, judgemental equality, and functionality requirements:

| Need | OOP Idiom (incompatible) | CTT Primitive | Propositions-as-Types (§V) |
|---|---|---|---|
| Variants | Class hierarchy + `instanceof` | Sum type $A_1 + A_2$ | Disjunction $\Phi_1 \lor \Phi_2$ |
| Composition | Mixins, multiple inheritance | Product type $A_1 \times A_2$ | Conjunction $\Phi_1 \land \Phi_2$ |
| Behavior | Virtual methods, vtable dispatch | Function type $A_1 \to A_2$ | Implication $\Phi_1 \supset \Phi_2$ |
| Indexed families | Generics with type erasure | Dependent function $a\!:\!A_1 \to A_2$ | Universal $\forall a\!:\!A.\, \Phi_a$ |
| Existential packaging | Abstract base class | Dependent pair $a\!:\!A_1 \times A_2$ | Existential $\exists a\!:\!A.\, \Phi_a$ |
| State change | Field mutation, setters | Algebraic effect $Op : B \times A^C \to A$ | (effect signature) |
| Nothing / absence | `null`, `nil`, `None` | Void type $0$ | Falsity $\bot$ |
| Trivial / done | Singleton with methods | Unit type $1$ | Truth $\top$ |

### Why these work

- **Sum types** are exhaustive: pattern matching must cover every variant, which makes elimination functions total. No `instanceof` check can miss a case. The canonical forms are structurally determined: $\text{inl}(M_\circ)$ or $\text{inr}(M_\circ)$, nothing else.

- **Product types** compose explicitly: $(M_1, M_2)$ is a canonical form whose components are independently accessible. No linearization order, no MRO ambiguity. The behavior of $M.1$ depends only on $M_1$, not on how the pair was assembled.

- **Function types** are extensionally equal: $M \doteq M' \in A_1 \to A_2$ iff for all $N \doteq N' \in A_1$, $\text{ap}(M, N) \doteq \text{ap}(M', N')$. The function's behavior is its *only* identity — there is no vtable, no class, no hidden dispatch.

- **Algebraic effects** make state changes explicit: an operation $Op : B \times A^C \to A$ declares its parameter type $B$ and continuation type $C$. The handler that interprets the effect is structurally present, not implicitly inherited through `self`. Effects compose via handler stacking, not class hierarchy.

## 5. Practical Implications for Implementation

These constraints do not prohibit the use of languages that *have* classes and mutation (Python, TypeScript, Java). They constrain how those features are used:

- **Use classes as namespaces for methods on data, not as inheritance hierarchies.** A `@dataclass` in Python or a `struct` in Rust is fine — it's a product type with named fields. A deep inheritance chain with virtual method overrides is not.

- **Use discriminated unions / tagged enums for variants, not subtype polymorphism.** Rust's `enum`, TypeScript's `type A = X | Y`, Python's `Union[X, Y]` with `match`/`if-isinstance` — these are sum types. A class hierarchy where each subclass overrides a method is implicit dispatch.

- **Treat mutation as an effect, not a default.** If a function must mutate state, use the language's effect-tracking mechanism (Rust's `&mut`, Python's explicit state passing, TypeScript's state management libraries). Never mutate shared state implicitly through `self` in a mixin.

- **Prefer value-semantic data.** Frozen dataclasses in Python, `readonly` interfaces in TypeScript, `#[derive(Clone)]` structs in Rust, `struct` value types in Swift. If the language permits mutation, opt out of it for domain types.

- **Make equality structural.** Implement `Eq`/`PartialEq` (Rust), `__eq__` (Python), or structural comparison (TypeScript) based on field values, never on reference identity.

Moldable patterns — inspectable objects, example-driven development, and contextual playgrounds — are the practical DX counterpart of CTT's "judgments as evidence." Just as CTT demands that every proposition has a constructive witness (proof term), moldable DX demands that every component has explorable evidence: example objects, traces, and runtime values. This aligns [component-model.md](./component-model.md) evidence and [moldable-canvas.md](./moldable-canvas.md) inspectability with the value-semantic discipline of §IX.

---

# X. The Agentic Stack: Rust, Python, TypeScript for Agent Systems

The harness-kit is a consummate CS/PLT theorist — but it is also a *pragmatic builder*. The formal foundations of §I–IX are not an end in themselves; they exist to produce **correct, maintainable, production-grade software**. This section identifies the three languages that, together, form the ideal stack for building AI agent systems, and explains why each is deeply suited to the CTT foundations and what state-of-the-art patterns to use in each.

## Why These Three

Each language occupies a distinct and complementary position in the CTT type-theoretic landscape:

| Layer | Language | CTT Role | What It Does Best |
|---|---|---|---|
| **Core Logic** | Rust | Domain (§I) + Dynamics (§II) | Provably correct algorithms, property-tested invariants, zero-cost abstractions, memory safety without GC |
| **Agentic / Orchestration** | Python | Effects (§VII) + Propositions (§V) | LLM orchestration, data analysis, ML workflows, human-in-the-loop agents, observability |
| **Interaction / UI** | TypeScript | Verifier (§III) + Products (§I.4) | Dashboards, real-time feedback, type-safe IPC, structural typing for domain mirroring |

**Together, they cover the full CTT:**
- Rust provides the **canonical forms** — the single source of truth for business logic, with `enum` sum types and ownership enforcing value semantics at the compiler level.
- Python provides the **effect layer** — LLM calls, tool invocations, and data pipelines are algebraic effects ($Op : B \times A^C \to A$), and Python's ecosystem (LangGraph, FastAPI, REDACTED) is the best-in-class platform for orchestrating them.
- TypeScript provides the **verification surface** — its structural type system is the closest mainstream analog to CTT's judgemental equality, and discriminated unions + `readonly` interfaces directly implement the §IX constraints.

**Connected via Diplomat FFI:** Rust ↔ TypeScript (via WASM), Rust ↔ Python (via C bindings + nanobind), all type-safe, all structurally verifiable.

## Rust: The Canonical Core

Rust is not merely "a fast language" — it is the mainstream language whose type system most closely embodies CTT's requirements:

### CTT Alignment

| CTT Concept | Rust Feature |
|---|---|
| Sum types ($A_1 + A_2$) | `enum` with exhaustive `match` — **native**, not a library |
| Product types ($A_1 \times A_2$) | `struct` with named fields |
| Function types ($A_1 \to A_2$) | `fn(A) -> B`, closures, no vtable dispatch for static dispatch |
| Value semantics (§IX.1) | Ownership + `Clone` — the compiler *enforces* that values are not aliased mutably |
| No null (§IX.4, Void) | `Option<T>` — absence is a sum type, not a sentinel value |
| Error as data (§VIII) | `Result<T, E>` — errors are values, `?` propagates structurally |
| Totality | Exhaustive `match`, `#[must_use]`, no implicit fallthrough |
| Deterministic equality (§III) | `Eq`/`PartialEq` derives — structural, never reference-based |
| Property testing | `proptest` — directly verifies CTT invariants via randomized canonical-form generation |

### State-of-the-Art Patterns

**Type-State Builder.** Encode construction phases in the type system so that incomplete objects are unrepresentable:

```rust
pub struct AgentBuilder<S: State> {
    config: AgentConfig,
    _state: PhantomData<S>,
}
pub struct Unconfigured;
pub struct Ready;

impl AgentBuilder<Unconfigured> {
    pub fn with_model(self, model: &str) -> AgentBuilder<Ready> {
        AgentBuilder { config: self.config.set_model(model), _state: PhantomData }
    }
}
impl AgentBuilder<Ready> {
    pub fn build(self) -> Agent { Agent::new(self.config) }
}
```

**Algebraic Error Hierarchies.** Use `thiserror` for domain errors as sum types:

```rust
#[derive(Debug, thiserror::Error)]
pub enum AgentError {
    #[error("model returned no response")]
    EmptyResponse,
    #[error("tool `{tool}` failed: {reason}")]
    ToolFailure { tool: String, reason: String },
    #[error("rate limit exceeded, retry after {retry_after_ms}ms")]
    RateLimited { retry_after_ms: u64 },
    #[error(transparent)]
    Io(#[from] std::io::Error),
}
```

**Property-Based Invariant Testing.** Every core algorithm gets proptest assertions that verify the CTT specification:

```rust
proptest! {
    #[test]
    fn rate_limiter_never_exceeds_capacity(
        requests in prop::collection::vec(any::<Request>(), 0..1000),
        capacity in 1u32..100,
    ) {
        let limiter = RateLimiter::new(capacity);
        let admitted: Vec<_> = requests.iter().filter(|r| limiter.check(r)).collect();
        prop_assert!(admitted.len() as u32 <= capacity);
    }
}
```

**Async Traits (stabilized).** For agent interfaces that cross async boundaries:

```rust
pub trait ToolProvider: Send + Sync {
    async fn invoke(&self, name: &str, args: serde_json::Value) -> Result<serde_json::Value, AgentError>;
    fn capabilities(&self) -> &[ToolCapability];
}
```

## Python: The Agentic Effect Layer

Python is not merely "easy to use" — its ecosystem is the dominant platform for AI agent orchestration, and its type system (with modern tooling) can enforce CTT constraints:

### CTT Alignment

| CTT Concept | Python Feature |
|---|---|
| Sum types ($A_1 + A_2$) | `Union[X, Y]`, `X \| Y` (3.10+), `match` statement for exhaustive elimination |
| Product types ($A_1 \times A_2$) | `@dataclass(frozen=True)`, `NamedTuple`, Pydantic `BaseModel(frozen=True)` |
| Algebraic effects (§VII) | `async/await` for I/O effects; LangGraph for agent effect orchestration; `@observe` for telemetry effects |
| Value semantics (§IX.1) | Frozen dataclasses, `NamedTuple`, Pydantic frozen models |
| Error as data (§VIII) | Typed exceptions with `raise`/`except`, or `Result`-like patterns via returns library |
| Structural typing (§III) | `Protocol` classes (PEP 544) — structural subtyping without inheritance |
| Totality | `mypy --strict` with exhaustiveness checking on `match` |
| Propositions as types (§V) | Pydantic models as specifications; validation *is* proof of conformance |

### State-of-the-Art Patterns

**Pydantic v2 Frozen Models as Canonical Forms.** Domain types are immutable, validated, and serializable — directly expressing CTT canonical forms:

```python
from pydantic import BaseModel, Field

class AgentConfig(BaseModel, frozen=True):
    """Agent configuration — immutable after construction (canonical form)."""
    model_name: str
    temperature: float = Field(ge=0.0, le=2.0, default=0.7)
    max_tokens: int = Field(gt=0, default=4096)
    tools: tuple[str, ...] = ()  # tuple, not list — immutable

class AgentResponse(BaseModel, frozen=True):
    """Agent response — value type with structural equality."""
    content: str
    tool_calls: tuple[ToolCall, ...] = ()
    usage: TokenUsage
```

**Sum Types via Tagged Unions.** Discriminated unions with exhaustive matching:

```python
from typing import Literal
from pydantic import BaseModel

class TextDelta(BaseModel, frozen=True):
    type: Literal["text_delta"] = "text_delta"
    content: str

class ToolCall(BaseModel, frozen=True):
    type: Literal["tool_call"] = "tool_call"
    name: str
    arguments: dict[str, object]

class Done(BaseModel, frozen=True):
    type: Literal["done"] = "done"
    usage: TokenUsage

type StreamEvent = TextDelta | ToolCall | Done  # Sum type

def handle_event(event: StreamEvent) -> str:
    match event:
        case TextDelta(content=c): return c
        case ToolCall(name=n): return f"Calling {n}..."
        case Done(): return "Complete."
```

**LangGraph with Typed State.** Agent orchestration with explicit typed state (the effect handler):

```python
from langgraph.graph import StateGraph
from typing import TypedDict

class AgentState(TypedDict):
    messages: list[HumanMessage | AIMessage]
    tool_results: list[ToolResult]
    plan: Plan | None

def create_react_agent(tools: list[BaseTool]) -> CompiledGraph:
    graph = StateGraph(AgentState)
    graph.add_node("reason", reason_node)
    graph.add_node("act", act_node)
    graph.add_conditional_edges("reason", should_act, {"act": "act", "done": END})
    graph.add_edge("act", "reason")
    graph.set_entry_point("reason")
    return graph.compile()
```

**Protocol Classes for Structural Typing.** Interfaces without inheritance — the CTT-correct way to specify behavior:

```python
from typing import Protocol, runtime_checkable

@runtime_checkable
class ToolProvider(Protocol):
    """Structural type — any class with these methods satisfies it, no inheritance needed."""
    async def invoke(self, name: str, args: dict) -> dict: ...
    def capabilities(self) -> list[str]: ...
```

**REDACTED Observability.** Every effect (LLM call, tool invocation, data access) is traced with sensitivity classification and data governance compliance — making effects *visible* and *auditable*, as required by §VII:

```python
import agentaware as aa
from agentaware import observe

aa.init(app_id="my-agent", default_sensitive_data_type="INTERNAL")

@observe(as_type="agent")
async def planning_agent(query: str) -> AgentResponse: ...

@observe(as_type="tool")
async def search_documents(query: str) -> list[Document]: ...

@observe(as_type="generation", name="gpt4-reasoning")
async def reason(messages: list[Message]) -> str: ...
```

## TypeScript: The Structural Verification Surface

TypeScript is not merely "JavaScript with types" — its structural type system is the closest mainstream analog to CTT's judgemental equality, making it uniquely suited to expressing and verifying the contracts that connect agents to users:

### CTT Alignment

| CTT Concept | TypeScript Feature |
|---|---|
| Sum types ($A_1 + A_2$) | Discriminated unions: `type A = {kind: "x"} \| {kind: "y"}` with exhaustive `switch` |
| Product types ($A_1 \times A_2$) | `interface` / `type` with named fields |
| Dependent-like indexing | Template literal types, conditional types, mapped types |
| Structural typing (§III) | **Native** — TypeScript checks structural compatibility, not nominal identity. This *is* judgemental equality on canonical forms. |
| Value semantics (§IX.1) | `readonly` modifier, `as const`, `Readonly<T>` utility type |
| Error as data (§VIII) | Discriminated union result types: `type Result<T, E> = {ok: true, value: T} \| {ok: false, error: E}` |
| Exhaustiveness checking | `never` type in default case of switch — the type system proves all variants are handled |
| Propositions as types (§V) | Zod schemas *are* specifications; `.parse()` *is* a proof of conformance |

### State-of-the-Art Patterns

**Discriminated Union Result Types.** Errors as data with exhaustive handling:

```typescript
type Result<T, E = Error> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: E };

type AgentError =
  | { readonly kind: "empty_response" }
  | { readonly kind: "tool_failure"; readonly tool: string; readonly reason: string }
  | { readonly kind: "rate_limited"; readonly retryAfterMs: number };

function handleError(error: AgentError): string {
  switch (error.kind) {
    case "empty_response": return "No response from model";
    case "tool_failure": return `Tool ${error.tool} failed: ${error.reason}`;
    case "rate_limited": return `Rate limited, retry in ${error.retryAfterMs}ms`;
    // TypeScript enforces exhaustiveness — missing a case is a compile error
  }
}
```

**Zod for Runtime Canonical Form Validation.** Schemas as specifications, parsing as proof:

```typescript
import { z } from "zod";

const AgentResponseSchema = z.object({
  content: z.string(),
  toolCalls: z.array(z.object({
    name: z.string(),
    arguments: z.record(z.unknown()),
  })).readonly(),
  usage: z.object({
    promptTokens: z.number().int().nonneg(),
    completionTokens: z.number().int().nonneg(),
  }),
}).readonly();

type AgentResponse = z.infer<typeof AgentResponseSchema>;
// Schema IS the specification; .parse() IS the proof of membership
```

**Readonly Domain Types with Structural Mirroring.** TypeScript interfaces mirror Rust structs exactly, with `readonly` enforcing value semantics:

```typescript
// Mirrors Rust: pub struct RateLimiterConfig { capacity: u32, window_ms: u64 }
export interface RateLimiterConfig {
  readonly capacity: number;
  readonly windowMs: number;
}

// Mirrors Rust: pub enum RateLimitResult { Allowed, Denied { retry_after_ms: u64 } }
export type RateLimitResult =
  | { readonly kind: "allowed" }
  | { readonly kind: "denied"; readonly retryAfterMs: number };
```

**Zustand for Explicit State Effects.** State changes are explicit operations (algebraic effects in spirit), not implicit mutations:

```typescript
import { create } from "zustand";
import { immer } from "zustand/middleware/immer";

interface AgentStore {
  readonly messages: readonly Message[];
  readonly isStreaming: boolean;
  // Actions are explicit effect operations
  sendMessage: (content: string) => Promise<void>;
  reset: () => void;
}

export const useAgentStore = create<AgentStore>()(
  immer((set) => ({
    messages: [],
    isStreaming: false,
    sendMessage: async (content) => {
      set((draft) => { draft.isStreaming = true; });
      const response = await agentApi.chat(content);
      set((draft) => {
        draft.messages.push(response);
        draft.isStreaming = false;
      });
    },
    reset: () => set({ messages: [], isStreaming: false }),
  }))
);
```

**Exhaustive Pattern Matching with `never`.** The type system proves totality:

```typescript
function assertNever(x: never): never {
  throw new Error(`Unexpected value: ${x}`);
}

function processEvent(event: StreamEvent): void {
  switch (event.type) {
    case "text_delta": renderText(event.content); break;
    case "tool_call": executeTool(event.name, event.arguments); break;
    case "done": finalize(event.usage); break;
    default: assertNever(event); // Compile error if a variant is missing
  }
}
```

## The Triad in Practice

In a typical agent system, the three languages compose as follows:

```
User ──→ TypeScript UI (React + Zustand)
              │
              │ Typed IPC / REST / WebSocket
              ▼
         Python Orchestrator (LangGraph + FastAPI + REDACTED)
              │
              │ LLM calls (generation effects)
              │ Tool invocations (tool effects)
              │ Data queries (retriever effects)
              ▼
         Rust Core (algorithms + data structures + Diplomat FFI)
              │
              │ Property-tested invariants
              │ Zero-cost canonical forms
              ▼
         Diplomat Bindings → WASM (TypeScript) / C (Python via nanobind)
```

**What flows between layers:**
- **TypeScript → Python:** User intents as typed request objects (product types, §I.4)
- **Python → Rust:** Domain data for processing as FFI-safe structs (canonical forms, §II.1)
- **Rust → Python:** Validated results as sum types (Result/Option, mapped to Python Union)
- **Python → TypeScript:** Agent responses as discriminated union streams (StreamEvent, §VII)

**What is verified at each boundary:**
- TypeScript Zod schema validates incoming data (judgemental equality, §III)
- Python Pydantic model validates domain objects (propositions as types, §V)
- Rust type system + proptest verifies invariants at compile time and test time (totality, §VIII)
- Diplomat FFI ensures type-safe crossing (functionality, §IV)

### X.1 Moldable Extensions

The agentic stack extends with moldable and hot-reload capabilities documented in forge.md and three companion specs. [moldable-canvas.md](./moldable-canvas.md) extends the DX layer with inspectability and runtime value persistence — components become explorable at development time. [component-model.md](./component-model.md) extends the polyglot component definition with evidence (Example Objects) and structured examples. [hot-reload.md](./hot-reload.md) adds safe state migration for live iteration across all three stack layers (Rust core, Python agentic, TypeScript UI). Together these specs realize forge.md's moldable/hot-reload vision within the CTT-grounded agentic stack.

---

# Appendix: Notation Summary

| Symbol | Meaning |
|---|---|
| $E\ \text{val}$ | $E$ is a canonical form (fully evaluated) |
| $E \mapsto E'$ | $E$ takes one computation step to $E'$ |
| $E \Downarrow E_\circ$ | $E$ evaluates to canonical form $E_\circ$ |
| $A\ \text{type}$ | $A$ is a type (i.e., $A \doteq A$) |
| $M \in A$ | $M$ is a member of type $A$ (i.e., $M \doteq M \in A$) |
| $M \doteq M' \in A$ | $M$ and $M'$ are equal elements of type $A$ |
| $A \doteq A'$ | $A$ and $A'$ are equal types |
| $\doteq_\circ$ | Equality of canonical forms |
| $a : A \gg J$ | Hypothetical judgement: $J$ holds assuming $a \in A$ |
| $B[M/a]$ | Substitution of $M$ for $a$ in $B$ |
| $\Gamma$ | Typing context (ordered list of hypotheses) |
