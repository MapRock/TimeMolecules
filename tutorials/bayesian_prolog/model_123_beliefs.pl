% Export from dbo.ModelEvents for ModelID = 1
% Format: belief(hypothesis(EventB), evidence([EventA]), Prob).

belief(hypothesis(depart), evidence([arrive]), 0.1).
belief(hypothesis(greeted), evidence([arrive]), 0.8).
belief(hypothesis(seated), evidence([arrive]), 0.1).
belief(hypothesis(depart), evidence([bigtip]), 1).
belief(hypothesis(charged1), evidence([ccdeclined]), 1).
belief(hypothesis(bigtip), evidence([charged]), 0.1429).
belief(hypothesis(ccdeclined), evidence([charged]), 0.1429).
belief(hypothesis(depart), evidence([charged]), 0.7143).
belief(hypothesis(depart), evidence([charged1]), 1).
belief(hypothesis(charged), evidence([check]), 1).
belief(hypothesis(order), evidence([drinks]), 1).
belief(hypothesis(seated), evidence([greeted]), 1).
belief(hypothesis(drinks), evidence([intro]), 0.875).
belief(hypothesis(order), evidence([intro]), 0.125).
belief(hypothesis(served), evidence([order]), 1).
belief(hypothesis(depart), evidence([seated]), 0.1111).
belief(hypothesis(intro), evidence([seated]), 0.8889).
belief(hypothesis(check), evidence([served]), 0.875).
belief(hypothesis(depart), evidence([served]), 0.125).