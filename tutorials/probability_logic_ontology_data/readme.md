# Seeing the Hook: Time Molecules, CEP, and the Enterprise Uncanny Valley

This document describes the Time Molecules process for the analysis of adversarial situations. That includes frauds, competitive games such as Texas Hold'em Poker, and any other situation where imperfect information is the key asset.

It lays out how Time Molecules pulls together <b>P</b>robability (Tuple Correlation Web and Time Molecules), <b>L</b>ogic (Prolog), <b>O</b>ntology (knowledge graphs), and <b>D</b>ata (BI semantic layer) into a foundation for a level of "enterprise awareness". I call it P.L.O.D. ... hahaha ... just my odd sense of humor.

I've written about my first major attempt at something like this in, [Conditional Trade-Off Graphs – Prolog in the LLM Era – AI 3rd Anniversary Special](https://eugeneasahara.com/2025/11/17/trade-off-semantic-network-prolog-in-the-llm-era-ai-3rd-anniversary-special/)

## Pros and Cons vs a Checklist

Many recognition algorithms apply a similarity score, a checklist of qualities, a one-dimensional structure. It could be more robust as a weighted checklist. But the problem with a weighted checklist is there are many ways to calculate a high, medium or low score. The combination does matter. For example, you can have a good BMI by being tall and of average weight for your height, or you could be shorter and very thin for your height.

Fish do not simply bite a hook because it resembles food. That sounds obvious, but it is a deeper idea than it first appears. A fish may recognize the worm, the movement, the color, the possibility of food. But at the same time, it may recognize something else: the odd gleam of metal, an unnatural bend, a stiffness in the movement, a smell that does not belong, a shape that does not fit any safe pattern.

The fish is not necessarily computing a single score.

It is not saying:

> 87 percent worm, 13 percent hook, therefore bite.

It may be recognizing two things at once:

> Food.
> Something wrong.

And the recognition of “something wrong” can override the recognition of food, depending on its level of hunger.

That is the heart of the problem enterprises now face with fraud, cyberattacks, scams, operational anomalies, supply-chain surprises, customer churn, and other rare but damaging events. The bad thing rarely arrives wearing a name tag. It arrives camouflaged as a normal event.

A login looks like a login.
A payment looks like a payment.
A vendor invoice looks like a vendor invoice.
A customer support request looks like a customer support request.
A sales opportunity looks like a sales opportunity.
A file download looks like a file download.

But something is off.

The action is a little too fast. The device is unfamiliar. The language is nearly right but not quite. The path through the process is legal, but strange. The event is not impossible. It is just not normal in the right way.

That is the enterprise uncanny valley. It's the level of "fish" intelligence (robust, multi-variate), as opposed to the higher level of "reptile intelligence" (iterative), then finally "human-level" intelligence (iterative recognition decoupled from a versatile selection of actions). See, [Levels of Intelligence – Prolog’s Role in the LLM Era, Part 6](https://eugeneasahara.com/2024/08/21/four-levels-of-intelligence-prologs-role-in-the-llm-era-part-6/) and [Reptile Intelligence: An AI Summer for CEP](https://eugeneasahara.com/2025/09/25/reptile-intelligence-an-ai-summer-for-cep/#CEP)

## The Enterprise Uncanny Valley

We usually think of the uncanny valley in terms of human-like robots or synthetic faces. Something is almost right, and because it is almost right, the small wrongness becomes disturbing. But the same principle applies to processes.

A scam email is not alarming because one or more features are blatantly wrong. It is alarming because many features are right. It mimics a trusted institution, a familiar workflow, a known person, a normal transaction, or a reasonable request. The scammer’s job is camouflage. The defender’s job is not merely classification. The defender’s job is to notice what the camouflage failed to hide.

That's why this is not just a machine-learning scoring problem. Scores from ML models usually consider a few input features, run it through a computation trained by an algorithm, and outputs a score. That score is only based on the parameter values. Granted those parameters were chosen because they are more "predictive" of an output than other potential parameters. This isn't a bad thing, in fact it's desireable. We don't want to make the model rigid, tied to what is in the training data, which probably won't reflect the world as it changes.

Because such ML "scores" consider only the most predictive parameters. A score can be useful, but a single score is often a compression of the very clues we need to preserve. In rare-event detection, the little things matter. Rare events are often perfect storms of many small factors. No one factor screams. But several tiny oddities, recognized together, change the meaning of the event.

This is closer to adversarial systems such as Texas Hold'em Poker the eternal struggle between predator and prey than to a checklist. In both systems, players rely on projecting as little information or deceitful information to their opponents as possible. A skilled poker player does not recognize a bluff by walking through a fixed list:

> Eye movement? Check.
> Breathing? Check.
> Chip handling? Check.
> Therefore bluff.

That kind of checklist can be gamed. A good bluffer learns the checklist. What gives them away is often something they did not know they were supposed to hide.

The same is true in fraud and cybersecurity. Attackers learn the obvious rules. They learn the scoring models. They learn the controls. So the frontier moves to the tiny signals they did not anticipate: timing, sequence, context, semantic mismatch, unusual property combinations, process path irregularity, environmental conditions, history, and what should have happened next but did not.

That is why an intelligent enterprise needs many senses.

In my blog, [Thousands of Senses](https://eugeneasahara.com/2025/06/15/thousands-of-senses/), the central point is that intelligence does not come from merely five broad senses, or even a few dozen inputs, but from access to a long tail of granular signals that can be selectively activated by context. The blog makes the enterprise analogy directly: IoT devices, AI agents, application logs, transactions, customer behavior, operational events, and other streams become sensory organs for the business. The issue is not simply “more data,” but more kinds of signals, available when the situation requires them. ([Soft Coded Logic][1])

That is the missing layer between ordinary CEP and process-aware intelligence.

## Why Ordinary CEP is not Enough

Complex Event Processing is already a powerful idea. Events stream through a system. Rules detect patterns. Windows aggregate activity. Alerts fire when known conditions appear.

That is important. It is the fast reflex layer.

But the problem with camouflage is that the known condition is often avoided. The scammer or attacker is deliberately trying not to match the obvious rule. The fish hook is designed to look like food. The phishing email is designed to look like business. The fraudulent transaction is designed to look like normal behavior. So the CEP layer needs help.

The event should still go to the regular CEP engine. We still need fast rule evaluation, windowing, thresholds, and immediate reactions. But beside that fast lane, there should be a deeper process-intelligence lane that asks:

> What process is this event part of?
> What usually comes next?
> What has this kind of event led to before?
> What good outcomes is it associated with?
> What bad outcomes is it associated with?
> Which properties make this instance different?
> Which knowledge graph concepts does this event touch?
> Which paths from this event lead toward risk, fraud, failure, churn, delay, escalation, **or opportunity**?

That deeper lane is where Time Molecules fits. Time Molecules can act as the system that says: this is not just an event. This is an event inside a case (a cycle) of a process, with case-level properties, event-level properties, semantic meaning, process history, and probable futures.

That changes the nature of detection. Instead of asking, “Is this event bad?” we can ask:

> What is this event becoming?

## Events are not Isolated Facts

Events that happen in the world are the result of upstream events and precede a number of downstream events, some bigger than others, perhaps all seemingly inconsequential, some perhaps disaterous. It order to analyze the effect:

1. Knowledge graphs (where events **types** are included as part of the ontology of the KG) can link the event to other phenomenon, particularly goals and risks we wish to avoid. To be clear, by "event", I don't mean each of the individual events that happen, for example, <i>Eugene purchased a pack of honeyberry seeds on 3/10/2026</i>. But the name of events such as arrive, depart, earthquake, sent text, woke up, ate lunch, etc.
2. Prolog scripts can estimate the probability of risks based on contemporary events. Note that Bayesian Conditional Probabilities act as a lighter, faster detection of probability (like System 1), where we could corroborate with deeper deductive capability of Prolog.

Let's look at an example. A login event is not just a login event.

It belongs to a case of a cycle of potential fraud. The case might be a session, a customer journey, an account lifecycle, an order, a shipment, an insurance claim, a support incident, a loan application, a patient encounter, or a security investigation.

The login also has event properties:

> device, IP range, geolocation, authentication method, browser fingerprint, time of day, failed attempts, velocity, requested resource, user agent, MFA behavior, previous event, next event.

The case has properties too:

> customer type, account age, risk tier, geography, normal activity pattern, open tickets, recent changes, known relationships, employee role, vendor status, current business context.

Now add Time Molecules. The event can be linked to one or more Markov model segments. That means the system can ask:

> In cases like this, when this event happens, what usually happens next?

That alone is powerful. But the key to success in an adversarial world is to correctly predict the next several steps. If a customer normally browses, compares, adds to cart, reviews shipping, and pays, but this case jumps from account recovery to stored payment update to high-value purchase to address change, the individual events may all be legal. But the path has the wrong shape.

This is where process awareness matters. The suspicious thing is not necessarily the event. It is the event in sequence.

The event can also be linked to Bayesian conditional probabilities:

> Given these properties, what is the probability of a chargeback?
> Given this event and this case context, what is the probability of account takeover?
> Given this sequence, what is the probability that the next event is escalation?
> Given this delay, what is the probability that the case fails its SLA?
> Given this supplier behavior, what is the probability of a shipment exception?

## Expanding the Ontology of Events with a Knowledge Graph 

The event registered in Time Molecules has an [International Resource Indicator (IRI)](https://eugeneasahara.com/glossary/#IRI). The properties of individual events may have IRIs. The database, table, column, source system, event type, and property definitions can all be grounded semantically. The event is not just the string `"PasswordResetRequested"` or `"InvoiceSubmitted"`. It is tied to an enterprise concept. That concept may be related to other concepts: authentication, credential recovery, identity risk, payment method, vendor trust, delivery exception, regulated data, privileged access, medical device, financial instrument, or customer distress.

This is where Time Molecules, Bayesian probabilities, Markov models, and the knowledge graph begin to form a process.

The Markov model tells us what tends to happen next.
The Bayesian layer tells us what conditions change the odds.
The knowledge graph tells us what this event and its properties mean.
The CEP layer gives us the immediate reflex.
The deeper Time Molecules layer gives us process memory.

## Recognition is not One Score

"Just one number, please." That's what my customer usually says when I respond with more than a single answer. Why do I respond with more than just one number? Because "it depends". A common enterprise pattern is to turn everything into a score:

> fraud score
> risk score
> churn score
> lead score
> health score
> anomaly score

Scores are useful. But a score is not the same as recognition.

Recognition can be simultaneous and contradictory.

A fish can recognize food and danger.
A poker player can recognize confidence, fear, and a huge opportunity.
A fraud system can recognize a valid customer and an account takeover pattern.
A security system can recognize a normal employee and a compromised device.
A supply-chain system can recognize a normal purchase order and a pattern that precedes disruption.

The point is not to collapse those recognitions too early.

The enterprise should preserve the independent recognitions:

> This looks like a normal payment.
> This also looks like a mule-account pattern.
> This looks like a real employee login.
> This also looks like impossible travel.
> This looks like an ordinary vendor invoice.
> This also looks like a vendor-bank-change scam.
> This looks like a hungry fish seeing food.
> This also looks like a fish seeing the hook.

Then the question becomes:

> Which recognition should dominate right now?

That answer is contextual.

A starving fish may bite despite uncertainty. A cautious fish may not. A novice may freeze in the presence of danger. A trained martial artist, surgeon, firefighter, or security analyst may act because experience lowers the cost of action. Not because danger is absent, but because skill changes the threshold.

Enterprises work the same way because every decision is really a matter of "it depends" to some degree.

A bank may tolerate friction for a high-risk wire transfer but not for a low-value coffee purchase. A hospital may allow a risky override in an emergency but not during routine administration. A cybersecurity system may challenge a user more aggressively during an active incident than during normal operations. An airline may tolerate unusual rebooking patterns during a storm but not on an ordinary Tuesday.

So the threshold to react should not be static.

It should depend on circumstance, experience, current threat level, user history, process state, business cost, and the skill or authority of the actor.

That is much richer than a fixed score.

## The Architecture: Fast CEP plus Deeper Time Molecules Reads

The architecture I would propose is not to replace CEP. It is to give CEP a deeper nervous system. CEP is <i>like</i> Kahneman's System 1 and Time Molecules is <i>like</i> System 2.

The event still enters the streaming platform. The fast CEP layer evaluates immediate rules:

> Is this on a deny list?
> Did the count exceed a window threshold?
> Did this exact forbidden sequence occur?
> Is this event malformed?
> Does this match a known attack or fraud pattern?

That layer is fast and deterministic.

But in parallel, the event is sent to a Time Molecules process-intelligence service. This service performs deeper reads, depending on urgency and available time.

The first level is “what comes next?”

This is the easiest and probably the most immediately useful. Given the event, the case properties, and the event properties, find the models that match this context. Then look up matching segments in `ModelEvents`. If the current event is `Event1A`, retrieve the likely `EventB` values, probabilities, counts, and elapsed-time statistics.

That gives the system a process-aware forecast:

> From here, cases like this usually go to these next events.
> These next events are good.
> These next events are bad.
> This case is currently moving toward something we want.
> This case is currently moving toward something we want to avoid.

The second level is semantic expansion through the knowledge graph.

The event’s IRI points to a semantic node. From that node, the system can traverse associations: parent concepts, related risks, expected effects, known bad outcomes, known good outcomes, compliance implications, process ownership, data lineage, source systems, and controls.

This can be cached. Most event types do not change their semantic neighborhood every second. The path from `PasswordResetRequested` to `AccountTakeoverRisk` or from `VendorBankAccountChanged` to `PaymentFraudRisk` can be precomputed or memoized.

The third level is property-level semantic search.

This is deeper and more expensive, but it is where many “hook glint” signals live. The event type may be normal, but a property may be odd. The amount, location, device, timing, text, chemical reading, temperature, delay, confidence level, source column, or unit of measure may carry the warning.

At this level, the system is not only asking:

> What does this event mean?

It is asking:

> What do these properties mean in this situation?

That is where a knowledge graph grounded in source metadata becomes valuable. The system can move from a raw property to its enterprise meaning: not just `col_237`, but `shipping temperature`, `privileged role`, `beneficiary account`, `dosage change`, `machine vibration`, `customer distress phrase`, or `unusual address distance`.

This is how “thousands of senses” becomes practical.

Not every event needs every sense. But the system needs the ability to pull in the right sense when the moment demands it.

See: [The Products of System 2 – Prolog in the LLM Era – Spring Break 2026 Special](https://eugeneasahara.com/2026/03/04/the-products-of-system-2/)

## The Query Pattern to Time Molecules

At the database level, the core procedure should be simple in concept:

> Accept an event, case properties, and event properties.
> Find all models that match those properties.
> Find matching `ModelEvents` rows where the current event is `Event1A`.
> Return likely next events, probabilities, supporting counts, elapsed-time measures, and semantic links.

In plain English, the stored procedure says:

> “Given what just happened, and given the kind of case this is, show me what usually happens next in comparable cases.”

That procedure becomes a bridge between CEP and Time Molecules.

The stored procedure signature is:

```sql
EXEC GetNextEventsForObservedEvent 
	@EventA = 'arrive', 
	@CasePropertiesJson='{"EmployeeID":1,"LocationID":1}', 
	@EventPropertiesJson=NULL,
	@TopN = 20
```

The exact implementation can evolve, but the responsibility should stay focused.

It should not try to do everything. It should not become the whole fraud engine, security engine, recommendation engine, or operations engine. Its job is to answer the process question:

> In comparable historical process contexts, what tends to follow this event?

The result set should be designed for both machines and humans:

| Output              | Meaning                                                       |
| ------------------- | ------------------------------------------------------------- |
| `ModelID`           | The matching process model                                    |
| `EventA`            | The observed/current event                                    |
| `EventB`            | A likely next event                                           |
| `Probability`       | Probability of `EventB` after `EventA` in that model          |
| `EventCount`        | Support behind the probability                                |
| `AvgElapsedTime`    | Typical time between events                                   |
| `StdDevElapsedTime` | Variability in timing                                         |
| `OutcomeClass`      | Optional semantic classification: good, bad, neutral, unknown |
| `EventB_IRI`        | Knowledge graph link for the predicted event                  |
| `ModelDescription`  | Human-readable explanation of the model                       |
| `ReasonContext`     | Which case/event properties caused this model to match        |

That last field matters. If the system says, “this looks risky,” the analyst should be able to see why this model was selected.

Was it because of geography?
Customer segment?
Device type?
Case type?
Transaction amount?
Event set?
Time window?
Source system?
Security role?
Product category?

This preserves explainability without pretending that the entire decision can be reduced to a single reason.

## The Relevance

A customer does not need another dashboard that says something is red.

They need a system that can say:

> This event is normal in isolation, but abnormal in this process context.
> This path often leads to a bad outcome.
> These properties are the ones that made this case comparable to prior bad cases.
> The next expected event did not occur.
> A different event occurred instead.
> The semantic meaning of that detour is important.
> We should slow down, ask for verification, route to review, or trigger a compensating process.

That is a much more practical vision than “AI will detect fraud.”

It is also more credible.

The system is not claiming magic. It is using observed event history, process models, conditional probabilities, semantic metadata, and knowledge graph associations to support better recognition.

That is exactly what enterprises are missing.

Most enterprise systems know transactions.
Some know entities.
Fewer know processes.
Almost none know the semantic meaning of process deviations in real time.

That is the gap Time Molecules can fill.

## The Hook, the Bluff, and the Process

The fish does not need a philosophy of fishing to avoid the hook. It only needs enough sensory richness to recognize that something about the worm is wrong.

The poker player does not need a formal theory of deception to call a bluff. They need enough experience to recognize that something in the performance does not fit the situation.

An enterprise does not need to wait for artificial general intelligence to defend itself better. It needs richer event streams, process memory, semantic grounding, and a way to preserve the little off-details instead of flattening them prematurely into a score.

That is the Time Molecules process idea.

A CEP system sees the event.
A Time Molecules system remembers what events like this become.
A knowledge graph understands what the event means.
Bayesian probabilities adjust the odds based on context.
The enterprise reacts only when the recognition of danger outweighs the recognition of normalcy, under the circumstances of the moment.

That is not just event processing, but process-aware recognition. In an environment where attackers, scammers, competitors, and even ordinary operational failures all arrive camouflaged as normal business, seeing the hook is the difference between intelligence and reaction.

Also see:

- [hypothetical_example_of_time_molecules_forecase_rare_events.md](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/business_application_intuition/hypothetical_example_of_time_molecules_forecase_rare_events.md) for a discussion on applications focused on rare events.

## PLOD Runthrough

Let's go through a sample runthrough of the PLOD mechanism. For simplicity, let's assume a slight level of dystopia. For example, cards in the wallet/purses/nametags of people can be readily read through RFID sensors. Events, such as detecting a person, is sent to a high-scale event processing system. 

Let's also assume that the host at the front desk is a human but not necessarily experienced with dealing with customers, so he gets some AI assistance from a trusty AI Agent we'll name Hudson.

We assume there is a high-scale event processing system that detects the arrival of a customer at one of our restaurants. His face is readily recognized by cameras monitoring the door. The system receives a json packet containing the customer's loyalty ID number (1), among other things.

It's rather busy, so the host is unable to greet the customer as soon as he walks in with his party. A good piece of information is to obtain a general idea of how patient this customer is. Keep in mind that the process to follow is invisible to the host.

### Query Time Molecules

A query is submitted to Time Molecules:

```sql
EXEC GetNextEventsForObservedEvent 
	@EventA = 'arrive', 
	@CasePropertiesJson='{"CustomerID":1,"LocationID":1}', 
	@EventPropertiesJson=NULL,
	@TopN = 20
```
These results are returned from Time Molecules:


| ModelID | StartDateTime | EndDateTime | EventSet | Metric | Transforms | ModelType | EventA | EventB | Prob | Rows | EventA_IRI | EventA_Description | EventB_IRI | EventB_Description |
|---:|---|---|---|---|---|---|---|---|---:|---:|---|---|---|---|
| 5 | 1900-01-01 00:00:00.000 | 2050-12-31 00:00:00.000 | restaurantguest | Time Between | NULL | MarkovChain | arrive | greeted | 1 | 2 | NULL | User arrives at location | NULL | User was greeted |
| 6 | 1900-01-01 00:00:00.000 | 2050-12-31 00:00:00.000 | restaurantguest | Time Between | NULL | MarkovChain | arrive | greeted | 1 | 1 | NULL | User arrives at location | NULL | User was greeted |

If the host was that output and were experienced, he would infer that he might want to place some priority on this customer who is known to leave. But what about other customers already there who are prone to leave or are powerfully mighty YouTube influencers? 

The AI continues to analyze. Next question for the AI is what do we know about customers who arrive and depart? Fortunately, subject-matter-experts have authored a knowledge graph that knows about such things.

### Adding the Knowledge Graph Check

The previous step asks Time Molecules a process question:

> Given that the customer arrived, what usually happens next?

In the restaurant example, the next event might be `greeted`, but it might also be something worse: the customer may leave before ordering.

The Time Molecules result can tell us that this path exists:

```text
arrive -> departed before ordering
````

That is already useful. But by itself, the Markov model only tells us the process path and its probability. The knowledge graph lets the AI agent ask a second question:

> If this customer is moving toward `departed before ordering`, what does that event mean, and why might it happen?

The full Turtle file for this example is here:

[restaurant_knowledge_graph.ttl](https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_hook/restaurant_knowledge_graph.ttl)

This is the important handoff:

1. CEP sees an event such as `arrive`.
2. Time Molecules checks comparable historical process paths.
3. The model says that `departed before ordering` is one possible next event.
4. The AI agent then checks the knowledge graph.
5. The knowledge graph returns the semantic meaning, possible risk reasons, affected business concepts, and expected event that was skipped.

In other words, the Time Molecule says:

```text
This path sometimes goes from arrive to departed before ordering.
```

The knowledge graph says:

```text
Departed before ordering is an abandonment event.
It prevents the expected ordered event.
It affects revenue opportunity, customer satisfaction, and waiting experience.
Possible reasons include excessive wait time, unpleasant greeting, crowding,
unappealing specials, host unavailable, or a confusing seating process.
```

That is a very small graph lookup, but it tells the AI agent a lot.

#### Salient TTL Segment

The full TTL contains more context, but the core idea is carried by a few triples.

First, `DepartedBeforeOrdering` is modeled as a kind of exception/abandonment event:

```turtle
tm:DepartureBeforeOrderingEvent
    a owl:Class ;
    rdfs:subClassOf tm:AbandonmentEvent ;
    rdfs:subClassOf tm:RestaurantEvent ;
    rdfs:label "Departure before ordering event" ;
    rdfs:comment "A restaurant event where the customer leaves before placing an order." .
```

Then the actual restaurant event is connected to the expected event it interrupts, the business concepts it affects, and the possible risk reasons:

```turtle
rest:DepartedBeforeOrdering
    a tm:DepartureBeforeOrderingEvent ;
    rdfs:label "departed before ordering" ;
    skos:prefLabel "departed before ordering" ;
    rdfs:comment "The customer leaves the restaurant before placing an order." ;
    tm:negativeOutcome true ;
    tm:preventsExpectedEvent rest:Ordered ;
    tm:affects rest:RevenueOpportunity ;
    tm:affects rest:CustomerSatisfaction ;
    tm:affects rest:WaitingExperience ;
    tm:hasRiskReason rest:ExcessiveWaitTime ;
    tm:hasRiskReason rest:UnpleasantGreeting ;
    tm:hasRiskReason rest:TooCrowded ;
    tm:hasRiskReason rest:UnappealingSpecials ;
    tm:hasRiskReason rest:HostUnavailable ;
    tm:hasRiskReason rest:ConfusingSeatingProcess .
```

The risk reasons are themselves semantic concepts:

```turtle
rest:ExcessiveWaitTime
    a tm:RiskReason ;
    a skos:Concept ;
    skos:prefLabel "Excessive wait time" ;
    skos:definition "The customer waits longer than expected or longer than they are willing to tolerate." ;
    tm:increasesRiskOf rest:DepartedBeforeOrdering ;
    skos:broader rest:WaitingExperience .

rest:UnpleasantGreeting
    a tm:RiskReason ;
    a skos:Concept ;
    skos:prefLabel "Unpleasant greeting" ;
    skos:definition "The customer is acknowledged in a way that feels rude, indifferent, rushed, or unwelcoming." ;
    tm:increasesRiskOf rest:DepartedBeforeOrdering ;
    skos:broader rest:ServiceEngagement .

rest:TooCrowded
    a tm:RiskReason ;
    a skos:Concept ;
    skos:prefLabel "Too crowded" ;
    skos:definition "The restaurant appears too full, noisy, cramped, or uncomfortable for the customer." ;
    tm:increasesRiskOf rest:DepartedBeforeOrdering ;
    skos:broader rest:RestaurantEnvironment .
```

The process links show that the bad path is a possible continuation from both `arrive` and `greeted`:

```turtle
rest:Arrive
    tm:usuallyFollowedBy rest:Greeted ;
    tm:usuallyFollowedBy rest:DepartedBeforeOrdering .

rest:Greeted
    tm:usuallyFollowedBy rest:Ordered ;
    tm:usuallyFollowedBy rest:DepartedBeforeOrdering .
```

That is the bridge between process mining and the semantic network. The process model tells the agent that this path can happen. The KG tells the agent what that path means.

#### SPARQL: Ask the KG Why the Customer Might Leave

After Time Molecules returns a possible next event such as `DepartedBeforeOrdering`, the AI agent can call the knowledge graph with a SPARQL query like this:

```sparql
PREFIX tm:   <https://timemolecules.com/ontology/>
PREFIX rest: <https://timemolecules.com/example/restaurant/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

SELECT
    ?riskEvent
    ?riskEventLabel
    ?preventedEventLabel
    ?affectedConceptLabel
    ?riskReasonLabel
    ?riskReasonDefinition
    ?broaderConceptLabel
WHERE {
    VALUES ?riskEvent { rest:DepartedBeforeOrdering }

    ?riskEvent rdfs:label ?riskEventLabel .

    OPTIONAL {
        ?riskEvent tm:preventsExpectedEvent ?preventedEvent .
        ?preventedEvent rdfs:label|skos:prefLabel ?preventedEventLabel .
    }

    OPTIONAL {
        ?riskEvent tm:affects ?affectedConcept .
        ?affectedConcept skos:prefLabel ?affectedConceptLabel .
    }

    OPTIONAL {
        ?riskEvent tm:hasRiskReason ?riskReason .
        ?riskReason skos:prefLabel ?riskReasonLabel .
        OPTIONAL { ?riskReason skos:definition ?riskReasonDefinition . }
        OPTIONAL {
            ?riskReason skos:broader ?broaderConcept .
            ?broaderConcept skos:prefLabel ?broaderConceptLabel .
        }
    }
}
ORDER BY ?riskReasonLabel ?affectedConceptLabel
```

The result gives the AI agent something like this:

| Risk event               | Prevented event | Affected concept      | Risk reason               | Broader concept        |
| ------------------------ | --------------- | --------------------- | ------------------------- | ---------------------- |
| departed before ordering | ordered         | revenue opportunity   | excessive wait time       | waiting experience     |
| departed before ordering | ordered         | customer satisfaction | unpleasant greeting       | service engagement     |
| departed before ordering | ordered         | waiting experience    | too crowded               | restaurant environment |
| departed before ordering | ordered         | waiting experience    | unappealing specials      | menu appeal            |
| departed before ordering | ordered         | customer satisfaction | host unavailable          | service engagement     |
| departed before ordering | ordered         | customer satisfaction | confusing seating process | service engagement     |

The exact row shape depends on the SPARQL engine and whether it expands the optional combinations, but the meaning is simple:

```text
The customer did not merely leave.
The customer abandoned the restaurant process before the order commitment event.
That abandonment affects revenue, satisfaction, and waiting experience.
The likely semantic reasons belong to waiting, greeting, environment, menu appeal,
and seating-process confusion.
```

#### SPARQL: Start from the Observed Event

The AI agent can also start from the event it just observed. For example, if CEP observes `arrive`, the agent can ask:

> What risky events are semantically connected to likely next events from `arrive`?

```sparql
PREFIX tm:   <https://timemolecules.com/ontology/>
PREFIX rest: <https://timemolecules.com/example/restaurant/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

SELECT
    ?observedEventLabel
    ?nextEventLabel
    ?riskReasonLabel
    ?riskReasonDefinition
    ?affectedConceptLabel
WHERE {
    VALUES ?observedEvent { rest:Arrive }

    ?observedEvent rdfs:label|skos:prefLabel ?observedEventLabel .
    ?observedEvent tm:usuallyFollowedBy ?nextEvent .
    ?nextEvent rdfs:label|skos:prefLabel ?nextEventLabel .

    OPTIONAL {
        ?nextEvent tm:hasRiskReason ?riskReason .
        ?riskReason skos:prefLabel ?riskReasonLabel .
        OPTIONAL { ?riskReason skos:definition ?riskReasonDefinition . }
    }

    OPTIONAL {
        ?nextEvent tm:affects ?affectedConcept .
        ?affectedConcept skos:prefLabel ?affectedConceptLabel .
    }
}
ORDER BY ?nextEventLabel ?riskReasonLabel
```

This query is intentionally simple. It is not trying to replace the Time Molecules model. The model should still provide the probabilities, counts, and elapsed-time statistics. The knowledge graph provides semantic expansion.

A combined agent response could look like this:

```text
Time Molecules found that after arrive, the customer usually moves to greeted,
but there is also a lower-probability path to departed before ordering.

The knowledge graph classifies departed before ordering as an abandonment event.
It prevents the expected ordered event and affects revenue opportunity, customer
satisfaction, and waiting experience.

Possible reasons include excessive wait time, unpleasant greeting, crowding,
unappealing specials, unavailable host, or confusing seating process.
```

#### The Value Add

This is the hook.

A conventional process query can say:

```text
arrive -> departed before ordering
```

A Time Molecules query can say:

```text
arrive -> departed before ordering
probability = 0.06
average elapsed time = 240 seconds
standard deviation = 95 seconds
```

The knowledge graph adds:

```text
departed before ordering is an abandonment event
it prevents ordered
it affects revenue opportunity
it affects customer satisfaction
it affects waiting experience
it has risk reasons
```

That turns a next-event prediction into an explanation surface.

The agent does not need a huge reasoning system to get value. With one additional KG call, it can move from:

> What is likely to happen next?

to:

> Why does this next event matter, what expected event was skipped, and what business concepts might explain or be affected by it?

That is the larger Time Molecules point. The Markov model supplies process memory. The knowledge graph supplies meaning. Together, they let an AI agent produce a more useful interpretation than either one could produce alone.

### Verbose Calculation of Risks

The KG tells the agent **what kinds of risks exist**.

Prolog can then calculate:

> Given this specific customer, in this specific situation, which risks are currently active?

The knowledge graph gives the AI agent the semantic map:

```text
DepartedBeforeOrdering
    has risk reason ExcessiveWaitTime
    has risk reason UnpleasantGreeting
    has risk reason TooCrowded
    has risk reason UnappealingSpecials
    has risk reason HostUnavailable
    has risk reason ConfusingSeatingProcess
````

But the knowledge graph does not, by itself, decide whether those risks apply to this specific customer right now.

That is the role of Prolog.

In this tutorial, Prolog is used as a lightweight reasoning layer. The rules can be authored from machine learning models, decision trees, scorecards, analyst rules, or other model outputs. The point is not that Prolog replaces machine learning. The point is that machine learning can produce usable risk logic, and that logic can be packaged into rules the AI agent can execute, inspect, and explain.

A machine learning model might discover patterns like this:

```text
Customers with low patience, during high crowding, after a slow greeting,
are much more likely to leave before ordering.
```

That pattern can be translated into Prolog as a rule:

```prolog
risk(Customer, excessive_wait_time, high) :-
    customer_patience(Customer, low),
    current_crowd_level(high),
    wait_time_seconds(Customer, Wait),
    Wait > 180.
```

Now the AI agent can combine three things:

| Layer           | Role                                                  |
| --------------- | ----------------------------------------------------- |
| Time Molecules  | What usually happens next in the process              |
| Knowledge Graph | What the next event means semantically                |
| Prolog          | Which risks apply to this specific customer right now |

The result is not just:

```text
arrive -> departed before ordering
```

It becomes:

```text
This customer is at elevated risk of departing before ordering because the current wait is long, the restaurant is crowded, and this customer profile has low tolerance for delay.
```

#### Example Prolog Risk Package

The Prolog file can be treated as a generated or authored risk package. It may be created by analysts, exported from machine learning models, or assembled from several Prolog fragments.

For example, here are three Prolog, that are separately created and maintained, but will merge into one. 

This first part is created from realtime information. This facial recognition camera (again, for the sake of explanation, please put aside the dystopian connotations), looks up the perform and returns information calculated from semantic layers (ex. [Kyvos Insights](https://www.kyvosinsights.com/)) formatted as Prolog. These "facts" are merged with the subsequent Prologs:

```prolog

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Customer qualities
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

customer_patience(customer_123, low).
customer_price_sensitivity(customer_123, medium).
customer_visit_intent(customer_123, quick_meal).
customer_loyalty_level(customer_123, new_customer).
```

This Prolog reflects the current conditions in the restaurant, particurlarly the lobby. Many of these facts could be inferred from cameras using "computer vision" models trained to recognize characteristics:

```prolog
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Contemporary restaurant features
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

current_crowd_level(high).
current_noise_level(high).
current_host_availability(low).
current_specials_appeal(low).
current_menu_visibility(medium).

wait_time_seconds(customer_123, 240).
greeting_quality(customer_123, neutral).
seating_process_clarity(low).
```
These are the risks Prolog. This Prolog probably needs to be authored primarily by humans. However, the humans can be assisted by LLMs and BI:

```prolog
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Restaurant premature departure risk rules
%
% These rules calculate risk reasons for a specific customer
% in the current restaurant situation.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

risk(Customer, excessive_wait_time, high) :-
    customer_patience(Customer, low),
    wait_time_seconds(Customer, Wait),
    Wait > 180.

risk(Customer, excessive_wait_time, medium) :-
    customer_patience(Customer, medium),
    wait_time_seconds(Customer, Wait),
    Wait > 240.

risk(Customer, too_crowded, high) :-
    current_crowd_level(high),
    current_noise_level(high),
    customer_visit_intent(Customer, quick_meal).

risk(Customer, host_unavailable, high) :-
    current_host_availability(low),
    wait_time_seconds(Customer, Wait),
    Wait > 120.

risk(Customer, unpleasant_greeting, medium) :-
    greeting_quality(Customer, poor).

risk(Customer, confusing_seating_process, medium) :-
    seating_process_clarity(low),
    customer_loyalty_level(Customer, new_customer).

risk(Customer, unappealing_specials, medium) :-
    current_specials_appeal(low),
    customer_price_sensitivity(Customer, medium).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Rollup rule
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

departure_before_ordering_risk(Customer, high) :-
    risk(Customer, excessive_wait_time, high).

departure_before_ordering_risk(Customer, high) :-
    risk(Customer, too_crowded, high),
    risk(Customer, host_unavailable, high).

departure_before_ordering_risk(Customer, medium) :-
    risk(Customer, confusing_seating_process, medium).

departure_before_ordering_risk(Customer, medium) :-
    risk(Customer, unappealing_specials, medium).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Explanation rule
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

departure_reason(Customer, Reason, Level) :-
    risk(Customer, Reason, Level).
```

The three Prolog above are merged. A simple Prolog query would be:

```prolog
departure_reason(customer_123, Reason, Level).
```

Possible result:

```text
Reason = excessive_wait_time,
Level = high

Reason = too_crowded,
Level = high

Reason = host_unavailable,
Level = high

Reason = confusing_seating_process,
Level = medium

Reason = unappealing_specials,
Level = medium
```

The AI agent can then join these Prolog results back to the knowledge graph.

The Prolog result says:

```text
excessive_wait_time is high
too_crowded is high
host_unavailable is high
```

The knowledge graph says:

```text
excessive wait time is broader than waiting experience
too crowded is broader than restaurant environment
host unavailable is broader than service engagement
```

So the agent can explain the result in business language:

```text
The customer is at high risk of leaving before ordering. The strongest active risks are excessive wait time, crowding, and host unavailability. Semantically, these risks point to problems in waiting experience, restaurant environment, and service engagement.
```

#### Who Authored the Prolog

The Prolog rules do not have to be hand-written from scratch.

They can be authored from machine learning outputs.

For example, a decision tree might produce a branch like this:

```text
IF wait_time_seconds > 180
AND customer_patience = low
THEN excessive_wait_time_risk = high
```

That can be converted to:

```prolog
risk(Customer, excessive_wait_time, high) :-
    customer_patience(Customer, low),
    wait_time_seconds(Customer, Wait),
    Wait > 180.
```

A second model might produce:

```text
IF crowd_level = high
AND visit_intent = quick_meal
THEN too_crowded_risk = high
```

Which becomes:

```prolog
risk(Customer, too_crowded, high) :-
    current_crowd_level(high),
    customer_visit_intent(Customer, quick_meal).
```

This is the neuro-symbolic handoff.

Machine learning discovers useful risk patterns.
Prolog packages those patterns into explicit, inspectable rules.
The knowledge graph gives those risks semantic meaning.
Time Molecules places the risk inside the actual process path.

#### Agent Flow

The agent flow now looks like this:

```text
1. CEP observes:
   customer_123 arrived

2. Time Molecules asks:
   What usually happens after arrive?

3. Time Molecules returns:
   arrive -> greeted
   arrive -> departed before ordering

4. The AI agent asks the KG:
   What is DepartedBeforeOrdering?

5. The KG returns:
   It is an abandonment event.
   It prevents Ordered.
   It affects RevenueOpportunity, CustomerSatisfaction, and WaitingExperience.
   It has risk reasons such as ExcessiveWaitTime, TooCrowded, HostUnavailable, etc.

6. The AI agent asks Prolog:
   Which of those risks are active for customer_123 right now?

7. Prolog returns:
   ExcessiveWaitTime = high
   TooCrowded = high
   HostUnavailable = high
   ConfusingSeatingProcess = medium

8. The agent responds:
   This customer is at high risk of leaving before ordering because the wait is already long,
   the restaurant is crowded, and the host is unavailable. These risks affect waiting
   experience, service engagement, and revenue opportunity.
```

#### How Does Prolog Fits Here

Prolog is useful here because this part of the problem is not merely statistical. It is conditional, explainable, and composable. It is the "L" in PLOD, Logic.

The agent is asking a question requiring a sophisticated answer, requiring a level of inference:

```text
What is the probability that the customer leaves?
```

It is asking:

- Why might this specific customer leave?
- Which risk reasons are active?
- Which features caused those risks?
- Which business concepts are affected?
- What expected event is being missed?


Those are rule-shaped questions.

The rule may have originated in machine learning, but once it is expressed as Prolog, it becomes something the agent can inspect and use.

That gives the system a useful separation of concerns:

| Component       | Question Answered                           |
| --------------- | ------------------------------------------- |
| CEP             | What just happened?                         |
| Time Molecules  | What usually happens next?                  |
| Knowledge Graph | What does that event mean?                  |
| Prolog          | Which risks apply to this case right now?   |
| LLM / AI Agent  | How should this be explained or acted upon? |


The knowledge graph gives the agent the menu of possible explanations.

Prolog determines which explanations apply to the current case.

So the KG might say:

```text
DepartedBeforeOrdering can be caused by excessive wait time, unpleasant greeting,
crowding, unappealing specials, host unavailability, or confusing seating.
```

But Prolog can say:

```text
For this customer, right now, the active risks are excessive wait time,
crowding, and host unavailability.
```

That provides enough information for a human or AI agent to make their priotization decisions.


The Time Molecule detects the process path.
The KG gives the path meaning.
Prolog calculates which risks are active.
The AI agent turns the combined result into a useful explanation.

See: [Knowledge Graphs vs Prolog – Prolog’s Role in the LLM Era, Part 7](https://eugeneasahara.com/2024/08/26/knowledge-graphs-vs-prolog-prologs-role-in-the-llm-era-part-7/)

#### Tying Back to the Data of the Semantic Layer

Time Molecules also facilitates a tie back to the database (BI data source, Semantic Layer, data warehouse, or event storage such as Azure CosmosDB) from which the events creating the Markov models were imported. This is the "D" in PLOD.

The following table is actually part of the result of the stored procedure, GetNextEventsForObservedEvent, way back in [Query Time Molecules](#Query-Time-Molecules):

| ModelID | EventA | EventA_Source_ServerName | EventA_Source_DatabaseName | EventA_SourceColumn_TableName | EventA_SourceColumn_ColumnName | EventB | EventB_Source_ServerName | EventB_Source_DatabaseName | EventB_SourceColumn_TableName | EventB_SourceColumn_ColumnName |
|---:|---|---|---|---|---|---|---|---|---|---|
| 5 | arrive | BI001 | Restaurant | Events | Event | greeted | BI001 | Restaurant | Events | Event
| 6 | arrive | BI001 | Restaurant | Events | Event | greeted | BI001 | Restaurant | Events | Event

That table displays metadata to the source of the events, particularly the name of the event (arrive, greeted). 

For example, suppose the database, BI001.Restaurant, is a modern, highly-performant Semantic Layer such as [Kyvos Insights](https://www.kyvosinsights.com/). Assuming we have access to that Semantic layer, we could connect to it and richly obtain further data towards facilitating high-qualty decisions. That's all the wonderful traditional BI information we've come to love over the decaades, such as Time series of the customer's recent profitability.

[1]: https://github.com/MapRock/TimeMolecules/tree/main/tutorials/time_molecules_hook "TimeMolecules/tutorials/time_molecules_hook at main · MapRock/TimeMolecules · GitHub"
[2]: https://github.com/MapRock/TimeMolecules/blob/main/tutorials/time_molecules_hook/restaurant_knowledge_graph.ttl "TimeMolecules/tutorials/time_molecules_hook/restaurant_knowledge_graph.ttl at main · MapRock/TimeMolecules · GitHub"


[1]: https://eugeneasahara.com/2025/06/15/thousands-of-senses/ "Thousands of Senses – Soft Coded Logic"
