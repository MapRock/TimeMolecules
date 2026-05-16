This <i>**hypothetical**</i> case study illustrates how Time Molecules could be applied in a modern AI-assisted enterprise without reducing the idea to ordinary single-process optimization.

The seed of Time Molecules begins with the CTO of a customer from about 20 years (ca. 2006ish) ago who told me that they can optimize sections of their business, but not as a whole. This might seem "duh" today, but it wasn't all those years ago in the BI world. It's been the "mission statement" I had been pursuing since then. 

# Hypothetical Case study: Kōlea Retail Health

Imagine a modern company called **Kōlea Retail Health**. It is a hybrid business: online retail, pharmacy, clinic services, subscription wellness products, delivery logistics, and AI-supported customer service.

It has all the normal enterprise systems:

```text
e-commerce platform
CRM
pharmacy system
clinic scheduling
warehouse management
delivery routing
customer support
finance / billing
marketing automation
AI agent platform
data warehouse / semantic layer
```

By 2026, the company has AI agents in production: support agents, product-recommendation agents, clinic scheduling agents, warehouse exception agents, and analyst copilots. That is not a wild assumption; current enterprise AI direction is already moving toward agentic workflows, cross-functional automation, and governance problems around scaling agents. Recent reporting also shows companies wrestling with agent reliability, rollbacks, safety systems, and custom context infrastructure as they move beyond pilots. 

The problem is not that Kōlea lacks data. It has too much data -- in depth (billions of rows) and breadth (across many diverse domains).

The problem is that **each department sees its own process**, but nobody has a durable model of how those processes shape each other.

## The Business Event

Kōlea launches an AI-personalized “Spring Allergy Relief” campaign.

The marketing agent identifies likely allergy customers and sends offers for:

```text
antihistamines
nasal sprays
air purifiers
clinic telehealth visits
same-day delivery bundles
subscription refills
```

On paper, the campaign is successful. The dashboard looks good, targets and goals are on-track. BI shows:

```text
campaign clickthrough up
online orders up
clinic bookings up
basket size up
same-day delivery requests up
```
But three days later, problems start appearing elsewhere:

```text
warehouse substitutions increase
pharmacy verification queues grow
delivery routes become unstable
support contacts spike
clinic no-shows increase
refunds rise
customers complain that AI recommendations conflicted with medication warnings
human pharmacists are interrupted more often
```

Each department has a local explanation. Marketing says the campaign worked. Fulfillment says inventory forecasting failed. Support says the AI agent overpromised. Pharmacy says clinical verification was not included early enough. Delivery says same-day windows were unrealistic.

Traditional BI can show all these metrics. But it struggles to answer the real question:

> **How did one process change propagate through the rest of the enterprise?**

That is the Time Molecules case study.

# What Time Molecules Adds

Kōlea uses Time Molecules as the **time-side semantic layer** for this business event.

It does not merely create one model of “the customer journey.” That would be too simplistic.

Instead, it models a **process neighborhood**.

## Process neighborhood

The campaign touches several linked processes:

| Process             | Example events                                                                       |
| ------------------- | ------------------------------------------------------------------------------------ |
| Marketing campaign  | `segment_created`, `offer_sent`, `offer_clicked`, `offer_accepted`                   |
| E-commerce          | `product_viewed`, `cart_added`, `checkout_started`, `order_placed`                   |
| Pharmacy            | `rx_checked`, `contraindication_flagged`, `pharmacist_reviewed`, `rx_released`       |
| Clinic scheduling   | `appointment_offered`, `appointment_booked`, `patient_checked_in`, `visit_completed` |
| Warehouse           | `pick_started`, `item_substituted`, `pack_completed`, `backorder_created`            |
| Delivery            | `route_assigned`, `driver_delayed`, `delivery_attempted`, `delivered`                |
| Support             | `chat_started`, `agent_answered`, `human_escalated`, `refund_requested`              |
| Finance             | `payment_authorized`, `refund_issued`, `subscription_cancelled`                      |
| AI agent operations | `agent_recommended`, `tool_called`, `policy_blocked`, `human_handoff`                |

These are separate processes. Time Molecules does not force them into one mega-flow.

It keeps them as separate cases, but links them through shared properties:

```text
CustomerID
CampaignID
OrderID
ProductID
LocationID
ClinicID
DeliveryRouteID
AgentID
RecommendationID
MedicationClass
SubstitutionReason
CallingCaseID
CallingEvent
CallingDateTime
```
See: [Linking cases](https://github.com/MapRock/TimeMolecules/tree/main/tutorials/link_cases)

That is where the enterprise value starts.

# The First Discovery: the campaign changed downstream paths

Before the campaign, the normal e-commerce model looked like this:

```text
offer_clicked -> product_viewed -> cart_added -> checkout_started -> order_placed
```

After the campaign, Time Molecules sees a new dominant path:

```text
offer_clicked -> bundle_recommended -> cart_added -> substitution_shown -> checkout_started -> order_placed
```

That by itself is not bad.

But when linked to warehouse cases, the system sees:

```text
substitution_shown -> order_placed
```

is strongly associated with:

```text
pick_started -> item_substituted -> support_contact
```

So the campaign did not just increase orders. It increased a particular kind of order that had downstream substitution risk.

Traditional BI might show substitution count increased.

Time Molecules shows the story fragment that propagated:

```text
AI bundle recommendation
  -> substitution exposure
  -> warehouse exception
  -> support contact
```

That is the difference.

# The second discovery: local AI success created cross-process load

The support AI agent has a KPI:

```text
reduce human escalations
```

During the campaign, the agent does reduce human escalations for simple product questions.

But Time Molecules links support cases to pharmacy cases and finds a different pattern:

```text
agent_answered -> customer_reordered -> contraindication_flagged -> pharmacist_reviewed
```

The agent is not doing anything illegal or obviously wrong. It is successfully encouraging reorder behavior.

But it is pushing extra review work into pharmacy because a subset of customers have medication conflicts, age restrictions, pregnancy flags, chronic conditions, or dosage questions.

The support process improved locally.

The pharmacy process degraded downstream.

This is the exact kind of cross-process effect that reflects the thesis of Time Molecules.

# The third discovery: a hidden state emerges

Kōlea creates Bayesian-style conditional probabilities.

For example:

```text
P(pharmacist_reviewed | agent_recommended, medication_warning_present)
```

and:

```text
P(refund_requested | item_substituted, delivery_delayed, agent_answered)
```

Then it creates Markov models sliced by:

```text
before campaign
during campaign
after campaign
campaign cohort
non-campaign cohort
AI recommendation type
product category
location
customer risk tier
```

A hidden state starts to appear. They call it:

```text
overpromised_allergy_bundle
```

It is not a literal event in one source system. It is a state inferred from a pattern:

```text
AI recommendation
+ limited inventory
+ pharmacy caution
+ same-day delivery promise
+ substitution exposure
```

That hidden state predicts a messy cross-process outcome:

```text
warehouse substitution
+ support contact
+ pharmacist review
+ refund request
+ subscription cancellation
```

Now Time Molecules is no longer just reporting what happened. It is helping the enterprise name a recurring cross-process story.

# What the executive sees

The executive does not need to see every Markov segment. They see something like this:

## Campaign result

| Area       | Local KPI              | Cross-process effect                           |
| ---------- | ---------------------- | ---------------------------------------------- |
| Marketing  | Offer conversion up    | Generated high-risk bundle paths               |
| E-commerce | Basket size up         | Increased substitution-sensitive orders        |
| Warehouse  | Pick volume up         | Substitution paths increased                   |
| Delivery   | Same-day orders up     | Route instability increased                    |
| Support AI | Human escalations down | Some issues deferred into pharmacy and refunds |
| Pharmacy   | Reviews up             | Clinical workload increased                    |
| Finance    | Revenue up initially   | Refunds and cancellations increased later      |

The key executive insight:

> The campaign did not simply succeed or fail. It changed the shape of work across the enterprise.

That is a very different thing from “conversion went up.”

# What Time Molecules stores

The system persists reusable model objects.

## Markov models

```text
Model: Campaign-to-order path, before campaign
Model: Campaign-to-order path, during campaign
Model: Warehouse exception path, campaign cohort
Model: Pharmacy review path, campaign cohort
Model: Support path, AI-agent-handled cases
Model: Finance/refund path, campaign cohort
```

## Conditional probabilities

```text
P(item_substituted | bundle_recommended)
P(pharmacist_reviewed | agent_recommended, warning_present)
P(refund_requested | item_substituted, delivery_delayed)
P(subscription_cancelled | refund_requested, support_contact)
```

## Model similarities

```text
Campaign cohort order model vs normal order model
AI-agent-handled support model vs human-handled support model
Warehouse model before vs during campaign
Refund path for substituted orders vs normal orders
```

## Linked cases

```text
Campaign case -> order case
Order case -> warehouse case
Order case -> pharmacy case
Order case -> delivery case
Support case -> refund case
Agent action case -> human escalation case
```

## FFT/signal models

For high-volume time series, it might also store FFT-like models:

```text
support contacts by hour
pharmacy review queue by hour
delivery delay minutes by route
warehouse substitution count by day
```

The point would be to see whether different signals share cycles, such as campaign send times, staffing schedules, delivery route congestion, or pharmacy review queues.

# The business decision

Without Time Molecules, the company might argue:

```text
Marketing says campaign worked.
Operations says it caused chaos.
Support says AI helped.
Pharmacy says AI hurt.
Finance says net value is unclear.
```

With Time Molecules, the company can make a more specific decision:

```text
The campaign works for allergy products when inventory confidence is high,
pharmacy risk is low, and same-day delivery capacity is available.

The campaign should be blocked or modified when the recommendation path includes:
- substitution-prone products
- medication warning flags
- constrained delivery windows
- high pharmacy queue load
```

The AI agent is not simply turned off.

It is made process-aware.

The new rule is not merely:

```text
Recommend allergy bundle.
```

It becomes:

```text
Recommend allergy bundle only when the downstream process neighborhood is healthy enough to absorb the recommendation.
```

That is a modern AI-era business capability.

# Why this is not ordinary process mining

The company is not just discovering one process map.

It is building a reusable memory of process interactions.

The important object is not:

```text
the e-commerce process
```

It is:

```text
the way an AI-personalized campaign changes e-commerce,
warehouse, pharmacy, delivery, support, and finance paths.
```

That is the Time Molecules distinction.

# How this becomes core capability

After the first campaign, Kōlea makes this a standard operating model.

Every major business change becomes an event:

```text
campaign launched
AI agent prompt changed
recommendation model updated
delivery promise policy changed
substitution policy changed
clinic schedule capacity changed
refund policy changed
pricing rule changed
```

For each change, Time Molecules compares before/after process neighborhoods.

The enterprise starts asking:

```text
What stories changed after this business change?
Which downstream models moved?
Which probabilities shifted?
Which process fragments became more common?
Which hidden states emerged?
Which local gains created downstream cost?
Which AI-agent actions changed human workload?
```

That is where it starts to look like BI.

BI made it normal to ask:

```text
How did revenue change by region, product, customer, and time?
```

Time Molecules makes it normal to ask:

```text
How did enterprise behavior change across interacting processes?
```

# A concise case-study version

```text
A hybrid retail-health company launches an AI-personalized allergy campaign.
Traditional BI shows that campaign conversion, basket size, and online revenue
increased. But the business also experiences warehouse substitutions, pharmacy
review backlogs, delivery delays, support contacts, refunds, and subscription
cancellations.

Time Molecules models this not as one process, but as a process neighborhood:
campaign, e-commerce, pharmacy, warehouse, delivery, support, finance, and AI-agent
operations. Each process keeps its own cases, but cases are linked through shared
properties such as CustomerID, CampaignID, OrderID, ProductID, AgentID, and
RecommendationID.

Markov models show how paths changed before and after the campaign. Bayesian-style
probabilities show which story fragments increased downstream risk, such as
P(refund_requested | bundle_recommended, item_substituted, delivery_delayed).
Model similarity compares normal order paths to campaign-cohort paths. FFT-style
models can identify shared cycles in support contacts, pharmacy queues, and delivery
delays.

The result is not simply “the campaign worked” or “the campaign failed.” The enterprise
learns how the campaign changed the shape of work across the business. The next
version of the AI agent does not merely optimize conversion. It checks whether the
downstream process neighborhood can absorb the recommendation before making it.
```

That is the concrete vision: **AI-era businesses need process-neighborhood awareness**, because intelligent local actions can create unintelligent enterprise behavior.

## Minimum Viable Implementation

A first implementation would not require the entire enterprise to be modeled. It would start with one business change and the process neighborhood around it:

1. Capture campaign, order, warehouse, delivery, support, pharmacy-review, and refund events.
2. Preserve shared keys such as CustomerID, CampaignID, OrderID, ProductID, AgentID, and RecommendationID.
3. Build baseline models for the same period before the campaign.
4. Build campaign-cohort models during the campaign.
5. Compare the before/during models.
6. Calculate conditional probabilities for selected downstream outcomes.
7. Expose the findings as BI-facing summaries and AI-agent-facing guardrails.

**However, the real first step** is to implement a [high-scale event processing system](https://github.com/MapRock/TimeMolecules/blob/main/docs/llm_prompts/time_molecules_high_scale_event_processing.md) to collect events from across very many sources. That wide view linked through the ubiquitous dimension of time is the key to Time Molecules.

