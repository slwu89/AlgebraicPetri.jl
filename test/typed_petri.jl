using Test

using Catlab.Programs, AlgebraicPetri, AlgebraicPetri.TypedPetri

const infectious_ontology = LabelledPetriNet(
  [:Pop],
  :infect=>((:Pop, :Pop)=>(:Pop, :Pop)),
  :disease=>(:Pop=>:Pop),
  :strata=>(:Pop=>:Pop)
)

sird_uwd = @relation () where (S::Pop, I::Pop, R::Pop, D::Pop) begin
  infect(S,I,I,I) # inf
  disease(I,R) # recover
  disease(I,D) # die
end

typed_sird = add_params(
  oapply_typed(infectious_ontology, sird_uwd, [:inf, :recover, :die]),
  Dict(:S => 1.0, :I => 1.0, :R => 0.0, :D => 0.0),
  Dict(:inf => 0.5, :recover => 1.0, :die => 0.2)
)

@test ns(typed_sird.dom) == 4
@test nt(typed_sird.dom) == 3

quarantine_uwd = @relation () where (Q::Pop, NQ::Pop) begin
  strata(Q,NQ) # enter quarantine
  strata(NQ,Q) # exit quarantine
end

typed_quarantine = add_params(
  oapply_typed(infectious_ontology, quarantine_uwd, [:exit_Q, :enter_Q]),
  Dict(:Q => 1.0, :NQ => 1.0),
  Dict(:exit_Q => 0.5, :enter_Q => 0.5)
)

typed_quarantine_aug = add_reflexives(
  typed_quarantine,
  [[:disease], [:disease, :infect]],
  infectious_ontology
)

typed_sird_aug = add_reflexives(
  typed_sird,
  [[:strata], [:strata], [:strata], []],
  infectious_ontology
)

stratified = typed_product(typed_quarantine_aug, typed_sird_aug)

@test ns(stratified.dom) == 8
@test nt(stratified.dom) == 6 + 4 + 1
@test typeof(stratified.dom[1,:sname]) == Tuple{Symbol, Symbol}
@test typeof(stratified.dom[1,:concentration]) == Tuple{Float64, Float64}
